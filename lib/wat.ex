defmodule Wat do
  @moduledoc """
  Wat keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  import Ecto.Query

  @app :wat

  env_keys = [
    :openai_api_key
  ]

  for key <- env_keys do
    def unquote(key)(), do: Application.fetch_env!(@app, unquote(key))
  end

  def list_similar_content(content, packages \\ [], anchor \\ nil)

  def list_similar_content(content, packages, anchor) when is_binary(content) do
    content
    |> OpenAI.embedding()
    |> list_similar_content(packages, anchor)
  end

  def list_similar_content(embedding, packages, _anchor = nil) when is_list(embedding) do
    %HNSWLib.Index{} = index = :persistent_term.get(:hnsw)

    with {:ok, labels, dists} <-
           HNSWLib.Index.knn_query(index, Nx.tensor(embedding, type: :f32), k: 20) do
      [ids] = Nx.to_list(labels)
      [dists] = Nx.to_list(dists)

      docs =
        "docs"
        |> where([d], d.id in ^ids)
        |> maybe_limit_packages(packages)
        |> select([d], %{
          id: d.id,
          title: d.title,
          ref: d.ref,
          package: d.package,
          doc: fragment("substr(?, 0, 300)", d.doc)
        })
        |> Wat.Repo.all()
        |> Map.new(fn %{id: id} = doc -> {id, doc} end)

      ids
      |> Enum.zip(dists)
      |> Enum.map(fn {id, dist} ->
        if doc = Map.get(docs, id) do
          doc
          |> Map.put(:similarity, 1 - dist)
          |> Map.update!(:doc, fn doc ->
            if byte_size(doc) == 299, do: doc <> "...", else: doc
          end)
        end
      end)
      |> Enum.reject(&is_nil/1)
    end
  end

  def list_similar_content(embedding, _packages, _anchor) when is_list(embedding) do
    []
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
    EmbeddedDoc
    |> where(id: ^id)
    |> Wat.Repo.update_all(set: [embedding: encode_embedding(embedding)])
  end

  def parse_query(query) do
    query
    |> String.split()
    |> Enum.reduce(%{packages: [], query: [], anchor: nil}, fn word, acc ->
      case word do
        "#" <> package -> Map.update!(acc, :packages, fn prev -> [package | prev] end)
        "@" <> package -> %{acc | anchor: package}
        _ -> Map.update!(acc, :query, fn prev -> [word | prev] end)
      end
    end)
    |> Map.update!(:query, fn words ->
      words |> :lists.reverse() |> Enum.join(" ")
    end)
  end

  def autocomplete(query, packages, _anchor = nil) do
    "docs"
    |> maybe_limit_packages(packages)
    |> join(:inner, [d], t in "autocomplete", on: d.id == t.rowid)
    |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 1000)
    |> where([d, t], fragment("? MATCH ?", t.title, ^quote_query(query)))
    |> select([d, t, p], %{
      id: d.id,
      package: d.package,
      ref: d.ref,
      # title: fragment("snippet(autocomplete, 0, '<b><i>', '</i></b>', '...', 100)"),
      title: d.title,
      rank: fragment("rank"),
      recent_downloads: p.recent_downloads
    })
    |> order_by([_, _, p], asc: fragment("round(rank / 5)"), desc: p.recent_downloads / 1_200_000)
    |> limit(25)
    |> Wat.Repo.all()
    |> case do
      [] -> autocomplete_spellfix(query, packages, _anchor = nil)
      [_ | _] = results -> results
    end
  end

  # def autocomplete(query, [], anchor) do
  #   graph0 = :persistent_term.get(:graph0)

  #   similarly_named = list_similarly_named(anchor)
  #   neighbors = nil
  #   # autocomplete(query, packages)
  #   # and reorder based on how close in deps graph?

  #   "docs"
  #   |> join(:inner, [d], t in "autocomplete", on: d.id == t.rowid)
  #   |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 1000)

  #   # |> where([d, t])
  # end

  # def list_similarly_named(package) do
  #   group =
  #     "similarly_named" |> where(package_group: ^package) |> select([s], s.package) |> Repo.all()

  #   case group do
  #     [] ->
  #       groups_q = "similarly_named" |> where(package: ^package) |> select([s], s.package_group)

  #       "similarly_named"
  #       |> where([s], s.package_group in subquery(groups_q))
  #       |> select([s], s.package)
  #       |> distinct(true)
  #       |> Repo.all()

  #     [_ | _] ->
  #       group
  #   end
  # end

  defp autocomplete_spellfix(query, packages, _anchor) do
    # combinations: json postges -> (json postgres, json postgis)
    # use union
    query
    |> String.split(" ")
    |> Enum.flat_map(&maybe_spellfix/1)
    |> Enum.flat_map(fn query ->
      "docs"
      |> maybe_limit_packages(packages)
      |> join(:inner, [d], t in "autocomplete", on: d.id == t.rowid)
      |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 3000)
      |> where([d, t], fragment("? MATCH ?", t.title, ^quote_query(query)))
      |> select([d, t, p], %{
        id: d.id,
        package: d.package,
        ref: d.ref,
        # title: fragment("snippet(autocomplete, 0, '<b><i>', '</i></b>', '...', 100)"),
        title: d.title,
        rank: fragment("rank"),
        recent_downloads: p.recent_downloads
      })
      |> order_by([_, _, p], fragment("rank") - p.recent_downloads / 1_200_000)
      |> limit(10)
      |> Wat.Repo.all()
    end)
    |> Enum.sort_by(fn d -> d.rank - d.recent_downloads / 1_200_000 end, :asc)
    |> Enum.take(25)
  end

  @spec maybe_spellfix(String.t()) :: [String.t()]
  def maybe_spellfix(term) do
    "autocomplete_spellfix"
    |> where([s], fragment("word match ? and top=3", ^term))
    |> select([s], map(s, [:word, :distance]))
    |> Wat.Repo.all()
    |> case do
      [%{word: ^term} | _rest] -> [term]
      fixes -> fixes |> Enum.filter(&(&1.distance < 200)) |> Enum.map(& &1.word)
    end
  end

  # TODO spellfix on fts_vocab?
  def fts(query, packages, _anchor = nil) do
    "docs"
    |> maybe_limit_packages(packages)
    |> join(:inner, [d], f in "fts", on: d.id == f.rowid)
    |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 1000)
    |> where([d, f], fragment("fts MATCH ?", ^quote_query(query)))
    |> select([d, f, p], %{
      id: d.id,
      package: d.package,
      ref: d.ref,
      title: fragment("snippet(fts, 0, '<b><i>', '</i></b>', '...', 10)"),
      doc: fragment("snippet(fts, 1, '<b><i>', '</i></b>', '...', 50)"),
      rank: fragment("rank"),
      recent_downloads: p.recent_downloads
    })
    |> order_by([_, _, p], fragment("rank") - p.recent_downloads / 1_200_000)
    |> limit(100)
    |> Wat.Repo.all()

    # |> case do
    #   [] -> fts_spellfix(query, packages, _anchor = nil)
    #   [_ | _] = results -> results
    # end
  end

  def fts(_query, _packages, _anchor) do
    []
  end

  # defp fts_spellfix(query, packages, _anchor) do
  #   query
  #   |> String.split(" ")
  #   |> Enum.flat_map(&maybe_spellfix/1)
  #   |> Enum.flat_map(fn query ->
  #     "docs"
  #     |> maybe_limit_packages(packages)
  #     |> join(:inner, [d], f in "fts", on: d.id == f.rowid)
  #     |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 3000)
  #     |> where([d, f], fragment("fts MATCH ?", ^quote_query(query)))
  #     |> select([d, f, p], %{
  #       id: d.id,
  #       package: d.package,
  #       ref: d.ref,
  #       title: fragment("snippet(fts, 0, '<b><i>', '</i></b>', '...', 10)"),
  #       doc: fragment("snippet(fts, 1, '<b><i>', '</i></b>', '...', 50)"),
  #       rank: fragment("rank"),
  #       recent_downloads: p.recent_downloads
  #     })
  #     |> order_by([_, _, p], fragment("rank") - p.recent_downloads / 1_200_000)
  #     |> limit(10)
  #     |> Wat.Repo.all()
  #   end)
  #   |> Enum.sort_by(fn d -> d.rank - d.recent_downloads / 1_200_000 end, :asc)
  #   |> Enum.take(20)
  # end

  defp maybe_limit_packages(query, []), do: query

  defp maybe_limit_packages(query, packages) do
    where(query, [d], d.package in ^packages)
  end

  defp quote_query(query) do
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
