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

  def list_similar_content(content, packages \\ [])

  def list_similar_content(content, packages) when is_binary(content) do
    content
    |> OpenAI.embedding()
    |> list_similar_content(packages)
  end

  def list_similar_content(embedding, packages) when is_list(embedding) do
    import Ecto.Query

    %HNSWLib.Index{} = index = :persistent_term.get(:hnsw)

    with {:ok, labels, dists} <-
           HNSWLib.Index.knn_query(index, Nx.tensor(embedding, type: :f32), k: 20) do
      [ids] = Nx.to_list(labels)
      [dists] = Nx.to_list(dists)

      docs =
        "docs"
        |> where([d], d.id in ^ids)
        |> maybe_limit_packages(packages)
        |> select([d], map(d, [:id, :title, :ref, :package, :doc]))
        |> Wat.Repo.all()
        |> Map.new(fn %{id: id} = doc -> {id, doc} end)

      ids
      |> Enum.zip(dists)
      |> Enum.map(fn {id, dist} ->
        if doc = Map.get(docs, id) do
          Map.put(doc, :similarity, 1 - dist)
        end
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  # def list_similar_content(embedding, packages) when is_list(embedding) do
  #   import Ecto.Query

  #   top =
  #     "docs"
  #     |> maybe_limit_packages(packages)
  #     |> where([d], not is_nil(d.embedding))
  #     |> select([d], map(d, [:id, :embedding]))
  #     |> Wat.Repo.all()
  #     |> Enum.map(fn doc ->
  #       similarity = cosine_similarity(decode_embedding(doc.embedding), embedding)
  #       Map.put(doc, :similarity, similarity)
  #     end)
  #     |> Enum.sort_by(& &1.similarity, :desc)
  #     |> Enum.take(10)

  #   similarities = Map.new(top, fn doc -> {doc.id, doc.similarity} end)

  #   "docs"
  #   |> where([d], d.id in ^Map.keys(similarities))
  #   |> select([d], map(d, [:id, :package, :title, :ref, :doc, :type]))
  #   |> Wat.Repo.all()
  #   |> Enum.map(fn doc -> Map.put(doc, :similarity, Map.fetch!(similarities, doc.id)) end)
  #   |> Enum.sort_by(& &1.similarity, :desc)
  # end

  # defp cosine_similarity(a, b), do: cosine_similarity(a, b, 0, 0, 0)

  # defp cosine_similarity([x1 | rest1], [x2 | rest2], s1, s2, s12) do
  #   cosine_similarity(rest1, rest2, x1 * x1 + s1, x2 * x2 + s2, x1 * x2 + s12)
  # end

  # defp cosine_similarity([], [], s1, s2, s12) do
  #   s12 / (:math.sqrt(s1) * :math.sqrt(s2))
  # end

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

  def search_title(query, packages) do
    import Ecto.Query

    "docs"
    |> maybe_limit_packages(packages)
    |> join(:inner, [d], t in "autocomplete", on: d.id == t.rowid)
    |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 100)
    |> where([d, t], fragment("? MATCH ?", t.title, ^clean_query(query)))
    |> select([d, t, p], %{
      id: d.id,
      package: d.package,
      ref: d.ref,
      title: d.title,
      rank: fragment("rank"),
      recent_downloads: p.recent_downloads
    })
    |> order_by([_, _, p], [fragment("round(rank)"), desc: p.recent_downloads])
    |> limit(25)
    |> Wat.Repo.all()
  end

  def search_doc(query, packages) do
    import Ecto.Query

    "docs"
    |> maybe_limit_packages(packages)
    |> join(:inner, [d], f in "docs_doc_fts", on: d.id == f.rowid)
    |> join(:inner, [d], p in "packages", on: d.package == p.name)
    |> where([d, f], fragment("docs_doc_fts MATCH ?", ^clean_query(query)))
    |> select([d, f, p], %{
      id: d.id,
      package: d.package,
      ref: d.ref,
      title: fragment("snippet(docs_doc_fts, 0, '<b><i>', '</i></b>', '...', 64)"),
      doc: fragment("snippet(docs_doc_fts, 1, '<b><i>', '</i></b>', '...', 100)"),
      rank: fragment("round(rank)") - p.recent_downloads / 100_000,
      recent_downloads: p.recent_downloads
    })
    |> order_by([_, _, p], fragment("round(rank)") - p.recent_downloads / 100_000)
    |> limit(20)
    |> Wat.Repo.all()
  end

  defp maybe_limit_packages(query, []), do: query

  defp maybe_limit_packages(query, packages) do
    import Ecto.Query
    where(query, [d], d.package in ^packages)
  end

  defp clean_query(query) do
    query
    |> String.split(" ")
    |> Enum.map(&maybe_escape_query/1)
    |> Enum.join(" OR ")
  end

  defp maybe_escape_query(query) do
    escaped =
      if String.contains?(query, "\"") do
        escape_query(query)
      else
        query
      end

    "\"" <> escaped <> "\""
  end

  defp escape_query(<<?", rest::bytes>>) do
    <<?", ?", escape_query(rest)::bytes>>
  end

  defp escape_query(<<c, rest::bytes>>) do
    <<c, escape_query(rest)::bytes>>
  end

  defp escape_query(<<>> = done), do: done
end
