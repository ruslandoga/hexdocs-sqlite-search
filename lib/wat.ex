defmodule Wat do
  @moduledoc """
  Wat keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @app :wat

  env_keys = [
    :openai_api_key
  ]

  for key <- env_keys do
    def unquote(key)(), do: Application.fetch_env!(@app, unquote(key))
  end

  @default_packages ["phoenix", "phoenix_live_view", "ecto", "ecto_sql"]

  def list_similar_content(content, packages \\ @default_packages)

  def list_similar_content(content, packages) when is_binary(content) do
    content
    |> OpenAI.embedding()
    |> list_similar_content(packages)
  end

  def list_similar_content(embedding, packages) when is_list(embedding) do
    import Ecto.Query

    top =
      "docs"
      |> where([d], d.package in ^packages)
      |> where([d], not is_nil(d.embedding))
      |> select([d], map(d, [:id, :embedding]))
      |> Wat.Repo.all()
      |> Enum.map(fn doc ->
        similarity = cosine_similarity(decode_embedding(doc.embedding), embedding)
        Map.put(doc, :similarity, similarity)
      end)
      |> Enum.sort_by(& &1.similarity, :desc)
      |> Enum.take(10)

    similarities = Map.new(top, fn doc -> {doc.id, doc.similarity} end)

    "docs"
    |> where([d], d.id in ^Map.keys(similarities))
    |> select([d], map(d, [:id, :package, :title, :ref, :doc, :type]))
    |> Wat.Repo.all()
    |> Enum.map(fn doc -> Map.put(doc, :similarity, Map.fetch!(similarities, doc.id)) end)
    |> Enum.sort_by(& &1.similarity, :desc)
  end

  defp cosine_similarity(a, b), do: cosine_similarity(a, b, 0, 0, 0)

  defp cosine_similarity([x1 | rest1], [x2 | rest2], s1, s2, s12) do
    cosine_similarity(rest1, rest2, x1 * x1 + s1, x2 * x2 + s2, x1 * x2 + s12)
  end

  defp cosine_similarity([], [], s1, s2, s12) do
    s12 / (:math.sqrt(s1) * :math.sqrt(s2))
  end

  def encode_embedding(embedding) when is_list(embedding) do
    embedding
    |> Enum.map(fn f32 -> <<f32::32-float-little>> end)
    |> IO.iodata_to_binary()
  end

  def encode_embedding(<<_::6144-bytes>> = encoded), do: encoded

  def decode_embedding(<<f32::32-float-little, rest::bytes>>) do
    [f32 | decode_embedding(rest)]
  end

  def decode_embedding(<<>>), do: []

  defmodule EmbeddedDoc do
    @moduledoc false
    use Ecto.Schema

    schema "docs" do
      field :embedding, :binary
    end
  end

  def update_embedding(id, embedding) do
    import Ecto.Query

    EmbeddedDoc
    |> where(id: ^id)
    |> Wat.Repo.update_all(set: [embedding: encode_embedding(embedding)])
  end

  def search_title(query, packages \\ @default_packages) do
    import Ecto.Query

    "docs"
    |> where([d], d.package in ^packages)
    |> join(:inner, [d], t in "docs_title_fts", on: d.id == t.rowid)
    |> where([d, t], fragment("? MATCH ?", t.title, ^clean_query(query)))
    |> select([d, t], %{
      id: d.id,
      package: d.package,
      ref: d.ref,
      title: d.title,
      rank: fragment("rank")
    })
    |> order_by([_], fragment("rank"))
    |> limit(10)
    |> Wat.Repo.all()
  end

  def search_doc(query, packages \\ @default_packages) do
    import Ecto.Query

    "docs"
    |> where([d], d.package in ^packages)
    |> join(:inner, [d], f in "docs_doc_fts", on: d.id == f.rowid)
    |> where([d, f], fragment("? MATCH ?", f.doc, ^clean_query(query)))
    |> select([d, f], %{
      id: d.id,
      package: d.package,
      ref: d.ref,
      title: d.title,
      doc: d.doc,
      rank: fragment("rank")
    })
    |> order_by([_], fragment("rank"))
    |> limit(10)
    |> Wat.Repo.all()
  end

  defp clean_query(query) do
    String.replace(query, ["."], " ")
  end
end
