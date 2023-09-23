defmodule Dev do
  require Logger
  alias Exqlite.Sqlite3

  # def doku_path do
  #   Path.expand("../doku")
  # end

  # def populate_packages do
  #   prefix = Path.join(doku_path(), "stats")

  #   prefix
  #   |> File.ls!()
  #   |> Enum.map(fn file ->
  #     name = String.trim_trailing(file, ".json")
  #     stats = prefix |> Path.join(file) |> File.read!() |> Jason.decode!()
  #     recent_downloads = get_in(stats, ["downloads", "recent"]) || 0
  #     %{"name" => name, "recent_downloads" => recent_downloads}
  #   end)
  #   |> Enum.chunk_every(1000)
  #   |> Enum.each(fn packages ->
  #     Repo.insert_all("packages", packages,
  #       log: false,
  #       on_conflict: {:replace, [:recent_downloads]}
  #     )
  #   end)
  # end

  #   def populate_docs do
  #     prefix = Path.join(doku_path(), "index")

  #     # max_recent_downloads = ("packages" |> select([p], max(p.recent_downloads)) |> Wat.Repo.one)
  #     # Wat.Repo.insert_all("packages", Enum.map(["elixir", "eex", "ex_unit", "iex", "logger", "mix"], &%{name: &1, recent_downloads: 5_000_000}))
  #     # Enum.map(["elixir", "eex", "ex_unit", "iex", "logger", "mix"], fn n -> n <> ".json" end)

  #     prefix
  #     |> File.ls!()
  #     |> Enum.each(fn file ->
  #       package = String.trim_trailing(file, ".json")
  #       Logger.debug("importing #{package}")

  #       Path.join(prefix, file)
  #       |> read_docs_items()
  #       |> Enum.map(fn item ->
  #         Map.take(item, ["ref", "title", "type", "doc"])
  #         |> Map.update!("type", fn type -> type || "extras" end)
  #         |> Map.put("package", package)
  #       end)
  #       |> Enum.chunk_every(1000)
  #       |> Enum.each(fn docs ->
  #         Repo.insert_all("docs", docs,
  #           log: false,
  #           on_conflict: {:replace, [:title, :type, :doc]}
  #         )
  #       end)
  #     end)
  #   end

  # TODO bench the search query against autocomplete with UNINDEXED package column

  # def populate_autocomplete do
  #   Repo.transaction(fn ->
  #     Repo.query!("drop table if exists autocomplete")
  #     # Repo.query!("drop table if exists autocomplete_for_spellfix")

  #     Repo.query!("""
  #     create virtual table autocomplete using fts5(
  #       title,
  #       tokenize='trigram', content='docs', content_rowid='id'
  #     )
  #     """)

  #     Repo.query!(
  #       """
  #       insert into autocomplete(rowid, title)
  #         select id, title from docs
  #           where type in ('behaviour', 'callback', 'exception', 'function', 'macro', 'macrocallback', 'opaque', 'type')
  #             and instr(title, ' ') = 0
  #       """,
  #       [],
  #       timeout: :infinity
  #     )

  #     "docs"
  #     |> where([d], d.type in ["extras", "module", "protocol"])
  #     |> select([d], %{rowid: d.id, title: d.title})
  #     |> Repo.stream(max_rows: 1000)
  #     |> Stream.map(fn doc -> Map.update!(doc, :title, &extras_title/1) end)
  #     |> Stream.chunk_every(1000)
  #     |> Enum.each(&Repo.insert_all("autocomplete", &1))

  #     "docs"
  #     |> where(type: "task")
  #     |> select([d], %{rowid: d.id, title: d.title})
  #     |> Repo.stream(max_rows: 1000)
  #     |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_task/1) end)
  #     |> Stream.chunk_every(1000)
  #     |> Enum.each(&Repo.insert_all("autocomplete", &1))
  #   end)
  # end

  #   def populate_autocomplete_spellfix do
  #     Repo.transaction(fn ->
  #       Repo.query!("drop table if exists autocomplete_for_spellfix")
  #       Repo.query!("drop table if exists autocomplete_vocab")
  #       Repo.query!("drop table if exists autocomplete_spellfix")

  #       Repo.query!("""
  #       create virtual table autocomplete_for_spellfix using fts5(title)
  #       """)

  #       Repo.query!(
  #         """
  #         insert into autocomplete_for_spellfix(title)
  #           select title from docs
  #             where type in ('behaviour', 'callback', 'exception', 'function', 'macro', 'macrocallback', 'opaque', 'type')
  #               and instr(title, ' ') = 0
  #         """,
  #         [],
  #         timeout: :infinity
  #       )

  #       "docs"
  #       |> where([d], d.type in ["extras", "module", "protocol"])
  #       |> select([d], %{title: d.title})
  #       |> Repo.stream(max_rows: 1000)
  #       |> Stream.map(fn doc -> Map.update!(doc, :title, &extras_title/1) end)
  #       |> Stream.chunk_every(1000)
  #       |> Enum.each(&Repo.insert_all("autocomplete_for_spellfix", &1))

  #       "docs"
  #       |> where(type: "task")
  #       |> select([d], %{title: d.title})
  #       |> Repo.stream(max_rows: 1000)
  #       |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_task/1) end)
  #       |> Stream.chunk_every(1000)
  #       |> Enum.each(&Repo.insert_all("autocomplete_for_spellfix", &1))

  #       Repo.query!("""
  #       create virtual table autocomplete_vocab using fts5vocab('autocomplete_for_spellfix', 'row')
  #       """)

  #       Repo.query!("""
  #       create virtual table autocomplete_spellfix using spellfix1();
  #       """)

  #       Repo.query!("""
  #       insert into autocomplete_spellfix(rank, word) select doc, term from autocomplete_vocab where doc > 1;
  #       """)

  #       Repo.query!("drop table autocomplete_for_spellfix")
  #       Repo.query!("drop table autocomplete_vocab")
  #       Repo.query!("vacuum")
  #       Repo.query!("pragma wal_checkpoint(truncate)")
  #     end)
  #   end

  #   def populate_fts do
  #     Repo.transaction(fn ->
  #       Repo.query!("drop table if exists fts")

  #       Repo.query!("""
  #       create virtual table fts using fts5(
  #         title, doc, package UNINDEXED,
  #         tokenize='porter', content='docs', content_rowid='id'
  #       )
  #       """)

  #       Repo.query!(
  #         """
  #         insert into fts(rowid, title, doc, package) select id, title, doc, package from docs
  #         """,
  #         [],
  #         timeout: :infinity
  #       )
  #     end)

  #     Repo.query!("insert into fts(fts) values('optimize')")
  #     Repo.query!("vacuum")
  #     Repo.query!("pragma wal_checkpoint(truncate)")
  #   end

  #   def packages_graph(min_downloads) do
  #     packages_q =
  #       "packages"
  #       |> where([p], p.recent_downloads >= ^min_downloads)
  #       |> select([p], p.name)

  #     "packages_edges"
  #     |> select([e], {e.source, e.target})
  #     |> join(:inner, [e], p in subquery(packages_q), on: p.name == e.source)
  #     |> join(:inner, [e], p in subquery(packages_q), on: p.name == e.target)
  #     |> order_by([e], e.source)
  #     |> Repo.all()
  #     |> Enum.reduce(Graph.new(), fn {source, target}, graph ->
  #       graph
  #       |> Graph.add_vertex(source)
  #       |> Graph.add_vertex(target)
  #       |> Graph.add_edge(source, target)
  #     end)
  #   end

  #   def packages_graph do
  #     "packages_edges"
  #     |> select([e], {e.source, e.target})
  #     |> order_by([e], e.source)
  #     |> Repo.all()
  #     |> Enum.reduce(Graph.new(), fn {source, target}, graph ->
  #       graph
  #       |> Graph.add_vertex(source)
  #       |> Graph.add_vertex(target)
  #       |> Graph.add_edge(source, target)
  #     end)
  #   end

  #   def neighbors(graph, package, degrees) do
  #     do_neighbors(graph, %{package => 0}, degrees + 1, _degree = 1)
  #   end

  #   def do_neighbors(_graph, neighbors, degree, degree) do
  #     Enum.group_by(
  #       neighbors,
  #       fn {_package, degree} -> degree end,
  #       fn {package, _degree} -> package end
  #     )
  #   end

  #   def do_neighbors(graph, neighbors, degrees, degree) do
  #     new_neighbors =
  #       neighbors
  #       |> Map.keys()
  #       |> Enum.reduce(neighbors, fn package, acc ->
  #         graph
  #         |> Graph.neighbors(package)
  #         |> Enum.reduce(acc, fn package, acc -> Map.put_new(acc, package, degree) end)
  #       end)

  #     if map_size(new_neighbors) == map_size(neighbors) do
  #       do_neighbors(graph, new_neighbors, degrees, degrees)
  #     else
  #       do_neighbors(graph, new_neighbors, degrees, degree + 1)
  #     end
  #   end

  #   # def neighbors(graph, packages, degree \\ 1, degrees) do
  #   #   wider_packages =
  #   #     Enum.reduce(packages, packages, fn {package, _info}, acc ->
  #   #       Enum.reduce(
  #   #         Graph.neighbors(graph, package),
  #   #         acc,
  #   #         fn package, acc ->
  #   #           Map.put_new(acc, package, %{degree: degree})
  #   #         end
  #   #       )
  #   #     end)

  #   #   cond do
  #   #     map_size(packages) == map_size(wider_packages) ->
  #   #       sort_by_downloads(wider_packages, count)

  #   #     map_size(wider_packages) >= count ->
  #   #       sort_by_downloads(wider_packages, count)

  #   #     true ->
  #   #       neighbors(graph, wider_packages, degree + 1, count)
  #   #   end
  #   # end

  #   def with_downloads(packages) when is_map(packages) do
  #     Map.new(packages, fn {degree, packages} ->
  #       {degree, with_downloads(packages, min_downloads(degree))}
  #     end)
  #   end

  #   def with_downloads(packages, min_downloads) when is_list(packages) do
  #     "packages"
  #     |> where([p], p.name in ^packages)
  #     |> where([p], p.recent_downloads > ^min_downloads)
  #     |> select([p], map(p, [:name, :recent_downloads]))
  #     |> order_by([p], desc: p.recent_downloads)
  #     |> Repo.all()
  #   end

  #   def similarly_named(package) do
  #     prefix = package <> "\\_%"
  #     infix = "%\\_" <> package <> "\\_%"
  #     suffix = "%\\_" <> package

  #     "packages"
  #     |> where([p], p.name != ^package)
  #     |> where([p], p.recent_downloads > 10)
  #     |> where(
  #       [p],
  #       fragment("? like ? escape '\\'", p.name, ^prefix) or
  #         fragment("? like ? escape '\\'", p.name, ^infix) or
  #         fragment("? like ? escape '\\'", p.name, ^suffix)
  #     )
  #     |> select([p], p.name)
  #     |> order_by([p], desc: p.recent_downloads)
  #     |> Repo.all()
  #   end

  #   def similarly_named_connected(graph, package) do
  #     package
  #     |> similarly_named()
  #     |> Enum.filter(fn similar_package ->
  #       separation_degree(graph, package, similar_package) < 4
  #     end)
  #   end

  #   @stdlib ["ex_unit", "logger", "eex"]

  #   def separation_degree(graph, package1, package2) do
  #     if package1 in @stdlib or package2 in @stdlib do
  #       1
  #     else
  #       do_separation_degree(graph, MapSet.new([package1]), package2, 0)
  #     end
  #   end

  #   defp do_separation_degree(graph, packages, package, degree) do
  #     if MapSet.member?(packages, package) do
  #       degree
  #     else
  #       new_packages =
  #         packages
  #         |> Enum.reduce(packages, fn package, acc ->
  #           graph
  #           |> Graph.neighbors(package)
  #           |> Enum.reduce(acc, fn package, acc -> MapSet.put(acc, package) end)
  #         end)

  #       if MapSet.size(new_packages) == MapSet.size(packages) do
  #         -1
  #       else
  #         do_separation_degree(graph, new_packages, package, degree + 1)
  #       end
  #     end
  #   end

  #   def create_similarly_named do
  #     Repo.query!("drop table if exists similarly_named")

  #     Repo.query!(
  #       "create table similarly_named(package text not null, package_group text not null) strict"
  #     )

  #     Repo.query!("create index similarly_named_package_index on similarly_named(package)")

  #     Repo.query!(
  #       "create index similarly_named_package_group_index on similarly_named(package_group)"
  #     )
  #   end

  #   def populate_similarly_named_groups(graph) do
  #     mappings =
  #       "packages"
  #       |> select([p], p.name)
  #       |> where([p], p.recent_downloads > 1000)
  #       |> Repo.all()
  #       |> Enum.reduce([], fn package, acc ->
  #         case similarly_named(package) do
  #           [] -> acc
  #           [_ | _] = similar -> [{package, similar} | acc]
  #         end
  #       end)
  #       |> Enum.flat_map(fn {group, packages} ->
  #         Enum.map(packages, fn package -> {package, group} end)
  #       end)
  #       |> Enum.group_by(fn {package, _} -> package end, fn {_, group} -> group end)
  #       |> Enum.flat_map(fn {package, groups} ->
  #         package
  #         |> deduplicate_group(groups, graph)
  #         |> Enum.map(fn group -> %{package: package, package_group: group} end)
  #       end)

  #     Repo.insert_all("similarly_named", mappings)
  #   end

  #   def list_similarly_named(package) do
  #     group =
  #       "similarly_named" |> where(package_group: ^package) |> select([s], s.package) |> Repo.all()

  #     case group do
  #       [] ->
  #         groups_q = "similarly_named" |> where(package: ^package) |> select([s], s.package_group)

  #         "similarly_named"
  #         |> where([s], s.package_group in subquery(groups_q))
  #         |> select([s], s.package)
  #         |> distinct(true)
  #         |> Repo.all()

  #       [_ | _] ->
  #         group
  #     end
  #   end

  #   def create_similar_packages do
  #     Repo.query!("drop table if exists similar_packages")

  #     Repo.query!("""
  #     create table similar_packages(
  #       name text,
  #       package_group text,
  #       recent_downloads integer
  #     ) strict
  #     """)

  #     Repo.query!("create index similar_packages_name_index on similar_packages(name)")
  #     Repo.query!("create index similar_packages_group_index on similar_packages(group)")
  #   end

  #   def similar_packages(package) do
  #     "similar_packages"
  #     |> where(name: ^package)
  #     |> select([p], p.package_group)
  #     |> Repo.one()
  #     |> case do
  #       nil ->
  #         []

  #       groups ->
  #         "similar_packages"
  #         |> where([p], p.package_group in ^groups)
  #         |> select([p], map(p, [:name, :recent_downloads]))
  #         |> order_by([p], desc: p.recent_downloads)
  #         |> Repo.all()
  #     end
  #   end

  #   # ex_cldr_calendars_format: [before: ["ex_cldr_calendars", "ex_cldr"], after: ["ex_cldr_calendars"]]

  #   # plug, ex_cldr, membrane, absinthe, logger, phoenix, ecto, ex_aws

  #   defp deduplicate_group(package, group, graph) do
  #     # 0. filter only connected packages
  #     connected_group =
  #       Enum.filter(group, fn group -> separation_degree(graph, group, package) < 4 end)

  #     # 1. find smallest common name
  #     # e.g. "phoenix" is smallest common for ["phoenix", "phoenix_pubsub", "aws"]
  #     smallest_group =
  #       Enum.reject(connected_group, fn package ->
  #         Enum.any?(connected_group, fn maybe_smaller_package ->
  #           unless package == maybe_smaller_package do
  #             String.contains?(package, maybe_smaller_package)
  #           end
  #         end)
  #       end)

  #     smallest_group
  #   end

  #   defp min_downloads(0), do: 1
  #   defp min_downloads(1), do: 100
  #   defp min_downloads(2), do: 15000
  #   defp min_downloads(3), do: 1_000_000
  #   defp min_downloads(4), do: 3_000_000

  #   def populate_embeddings do
  #     {:ok, sup} = Task.Supervisor.start_link()

  #     "docs"
  #     |> join(:inner, [d], p in "packages", on: d.package == p.name)
  #     |> where([_, p], p.recent_downloads > 1_000_000 or p.name in ["ch", "ecto_ch"])
  #     |> where([d], d.doc != "##")
  #     # |> where(type: "extras")
  #     |> where([d], is_nil(d.embedding))
  #     |> limit(100)
  #     |> select([d], map(d, [:id, :doc]))
  #     |> Repo.all()
  #     |> populate_embeddings_continue(sup)
  #   end

  #   defp populate_embeddings_continue([], sup) do
  #     :ok = Supervisor.stop(sup)
  #   end

  #   defp populate_embeddings_continue(docs, sup) do
  #     Task.Supervisor.async_stream_nolink(
  #       sup,
  #       docs,
  #       fn %{id: id, doc: doc} ->
  #         IO.inspect(id)
  #         populate_embedding(id, doc)
  #       end,
  #       max_concurrency: 100,
  #       ordered: false,
  #       timeout: :timer.seconds(10)
  #     )
  #     |> Stream.run()

  #     populate_embeddings()
  #   end

  #   def populate_embedding(id, doc) do
  #     Wat.update_embedding(id, OpenAI.embedding(doc))
  #   end

  #   def read_docs_items(file) do
  #     json = File.read!(file)

  #     docs =
  #       case Jason.decode(json) do
  #         {:ok, docs} ->
  #           docs

  #         {:error, %Jason.DecodeError{}} ->
  #           fixed_json = fix_json(json)

  #           case Jason.decode(fixed_json) do
  #             {:ok, docs} ->
  #               docs

  #             {:error, %Jason.DecodeError{position: position} = error} ->
  #               Logger.error(file: file, section: binary_slice(fixed_json, position - 10, 20))
  #               raise error
  #           end
  #       end

  #     case docs do
  #       %{"items" => items} -> items
  #       items when is_list(items) -> items
  #     end
  #   end

  #   # https://github.com/elixir-lang/ex_doc/commit/60dfb4537549e551750bc9cd84610fb475f66acd
  #   defp fix_json(json) do
  #     json
  #     # |> String.replace("\\#\{", "\#{")
  #     |> to_json_string(<<>>)
  #   end

  #   # [file: "monad_cps.json", section: "gt;&gt;= \\a -&gt; Mo"]
  #   defp to_json_string(<<" \\a", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "a">>)

  #   # [file: "figlet.json", section: "en: flf2a\\d 4 3 8 15"]
  #   defp to_json_string(<<"\\d", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "d">>)

  #   # [file: "phoenix.json", section: "lo_dev=# \\d List of "]
  #   defp to_json_string(<<"\\\\d", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "d">>)

  #   # [file: "puid.json", section: "VWXYZ[]^_\\abcdefghij"]
  #   defp to_json_string(<<"_\\a", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "_a">>)

  #   # [file: "fluminus.json", section: "of nusstu\\e0123456)."]

  #   defp to_json_string(<<"u\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "ue">>)

  #   # [file: "boxen.json", section: "t; &quot;\\e[31m&quot"]
  #   defp to_json_string(<<";\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, ";e">>)

  #   # [file: "boxen.json", section: "4mhello, \\e[36melixi"]
  #   defp to_json_string(<<", \\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, ", e">>)

  #   # [file: "boxen.json", section: "36melixir\\e[0m&quot;"]
  #   defp to_json_string(<<"r\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "re">>)

  #   # [file: "chi2fit.json", section: "2fit.Fit \\e [ 0 m \\e"]
  #   defp to_json_string(<<" \\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, " e">>)

  #   # [file: "chi2fit.json", section: "ic Errors\\e[0m e [ 0"]
  #   defp to_json_string(<<"s\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "se">>)

  #   #  [file: "chi2fit.json", section: "formation\\e[0m e [ 0"]
  #   defp to_json_string(<<"n\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "ne">>)

  #   # [file: "owl.json", section: "36m┌─\\e[31mRed!\\"]
  #   defp to_json_string(<<"┌─\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "┌─e">>)

  #   # [file: "ex_unit_release.json", section: "ot;e[32m.\\e[0m Finis"]
  #   defp to_json_string(<<".\\e", rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, ".e">>)

  #   # [file: "cassandrax.json", section: "\"},{\"doc\":<<65, 32, "]
  #   defp to_json_string(<<"\"doc\":<<", rest::bytes>>, acc),
  #     do: to_json_string(rest, <<acc::bytes, "\"doc\":\"<<">>)

  #   # [file: "cassandrax.json", section: "2, ...>>,\"ref\":\"Cass"]
  #   defp to_json_string(<<">>,\"", rest::bytes>>, acc),
  #     do: to_json_string(rest, <<acc::bytes, ">>\",\"">>)

  #   # [file: "ecto.json", section: "ength, \\\"\\\#{Keyword."]
  #   defp to_json_string(<<"\\\#{", rest::bytes>>, acc),
  #     do: to_json_string(rest, <<acc::bytes, "\#{">>)

  #   defp to_json_string(<<?\b, rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "\\b">>)

  #   defp to_json_string(<<?\t, rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "\\t">>)

  #   defp to_json_string(<<?\n, rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "\\n">>)

  #   defp to_json_string(<<?\f, rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "\\f">>)

  #   defp to_json_string(<<?\r, rest::binary>>, acc),
  #     do: to_json_string(rest, <<acc::binary, "\\r">>)

  #   defp to_json_string(<<x, rest::binary>>, acc) when x <= 0x000F,
  #     do: to_json_string(rest, <<acc::binary, "\\u000#{Integer.to_string(x, 16)}">>)

  #   defp to_json_string(<<x, rest::binary>>, acc) when x <= 0x001F,
  #     do: to_json_string(rest, <<acc::binary, "\\u00#{Integer.to_string(x, 16)}">>)

  #   defp to_json_string(<<x, rest::binary>>, acc), do: to_json_string(rest, <<acc::binary, x>>)
  #   defp to_json_string(<<>>, acc), do: acc

  #   def count_embeddings do
  #     "docs" |> where([d], not is_nil(d.embedding)) |> Repo.aggregate(:count)
  #   end

  #   def stream_embeddings(callback) when is_function(callback, 1) do
  #     Repo.transaction(
  #       fn ->
  #         "docs"
  #         |> where([d], not is_nil(d.embedding))
  #         |> select([d], map(d, [:id, :embedding]))
  #         |> Repo.stream()
  #         |> callback.()
  #       end,
  #       timeout: :infinity,
  #       max_rows: 1000
  #     )
  #   end

  #   def make_hnsw_index do
  #     with {:ok, index} <-
  #            HNSWLib.Index.new(_space = :cosine, _dim = 1536, _max_elements = count_embeddings()) do
  #       stream_embeddings(fn stream ->
  #         stream
  #         |> Stream.chunk_every(1000)
  #         |> Stream.each(fn chunk ->
  #           IO.puts("adding items...")
  #           tensor = chunk |> Enum.map(&Wat.decode_embedding(&1.embedding)) |> Nx.tensor(type: :f32)
  #           :ok = HNSWLib.Index.add_items(index, tensor, ids: Enum.map(chunk, & &1.id))
  #         end)
  #         |> Stream.run()

  #         index
  #       end)
  #     end
  #   end

  #   def list_similar_content(query) when is_binary(query) do
  #     query |> OpenAI.embedding() |> list_similar_content()
  #   end

  #   def list_similar_content(embedding) when is_list(embedding) do
  #     %HNSWLib.Index{} = index = :persistent_term.get(:hnsw)

  #     with {:ok, labels, dists} <-
  #            HNSWLib.Index.knn_query(index, Nx.tensor(embedding, type: :f32), k: 10) do
  #       [ids] = Nx.to_list(labels)
  #       [dists] = Nx.to_list(dists)

  #       docs =
  #         "docs"
  #         |> where([d], d.id in ^ids)
  #         |> select([d], map(d, [:id, :title, :ref, :package, :doc]))
  #         |> Repo.all()
  #         |> Map.new(fn %{id: id} = doc -> {id, doc} end)

  #       ids
  #       |> Enum.zip(dists)
  #       |> Enum.map(fn {id, dist} -> docs |> Map.fetch!(id) |> Map.put(:similarity, 1 - dist) end)
  #     end
  #   end

  #   # "docs"
  #   #   |> maybe_limit_packages(packages)
  #   #   |> join(:inner, [d], t in "autocomplete", on: d.id == t.rowid)
  #   #   |> join(:inner, [d], p in "packages", on: d.package == p.name and p.recent_downloads > 1000)
  #   #   |> where([d, t], fragment("? MATCH ?", t.title, ^quote_query(query)))
  #   #   |> select([d, t, p], %{
  #   #     id: d.id,
  #   #     package: d.package,
  #   #     ref: d.ref,
  #   #     # title: fragment("snippet(autocomplete, 0, '<b><i>', '</i></b>', '...', 100)"),
  #   #     title: d.title,
  #   #     rank: fragment("rank"),
  #   #     recent_downloads: p.recent_downloads
  #   #   })
  #   #   |> order_by([_, _, p], fragment("rank") - p.recent_downloads / 1_200_000)
  #   #   |> limit(25)

  #   def autocomplete(package, query) do
  #     Repo.query!(
  #       """
  #       with recursive neighbors as (
  #         select e.target, 1 as distance
  #           from packages_edges e
  #           join packages p on e.target = p.name
  #           where e.source = ? and p.recent_downloads > 10000
  #         union
  #         select e.target, n.distance + 1
  #           from neighbors n
  #           join packages_edges e on n.target = e.source
  #           join packages p on e.target = p.name
  #           where n.distance <= 2 and p.recent_downloads > pow(10, n.distance + 4)
  #       )
  #       (
  #         select d.id, d.title, a.rank from docs d
  #         inner join autocomplete a on d.id = a.rowid
  #         inner join neighbors n on d.package = n.target
  #         where a.title match ?
  #         order by rank
  #         limit 10
  #       )
  #       union
  #       (
  #         select d.id, d.title, a.rank from docs d
  #         inner join autocomplete a on d.id = a.rowid
  #         inner join packages p on d.package = p.name
  #         where a.title match ?
  #         order by rank
  #         limit 10
  #       )
  #       """,
  #       [package, query]
  #     ).rows
  #   end

  #   # sqlite> select a.title from autocomplete a inner join docs d on d.id = a.rowid inner join packages p on d.package = p.name where a.title match 'phoenix json' order by rank / 5 - p.recent_downloads / 1000000 limit 10;
  #   # ┌──────────────────────────────────┐
  #   # │              title               │
  #   # ├──────────────────────────────────┤
  #   # │ Phoenix.json_library/0           │
  #   # │ Phoenix.Controller.json/2        │
  #   # │ Phoenix.Controller.allow_jsonp/2 │
  #   # │ Phoenix.ConnTest.json_response/2 │
  #   # │ PhoenixJsonLogger                │
  #   # │ PhoenixSwagger.JsonApi           │
  #   # │ PhoenixSwagger.JsonApi           │
  #   # │ PhoenixJsonLogger.log/4          │
  #   # │ Phoenix.Pagination.JSON          │
  #   # │ PhoenixJsonLogger.call/2         │
  #   # └──────────────────────────────────┘
  #   # Run Time: real 0.010 user 0.004396 sys 0.003915

  #   # """
  #   # select d.id, d.title, a.rank from docs d
  #   # inner join autocomplete a on d.id = a.rowid
  #   # inner join packages p on d.package = p.name and p.recent_downloads > 2000000 and p.name != 'hex_core'
  #   # where a.title match '"all"'
  #   # order by rank
  #   # limit 10;
  #   # """

  #   # """
  #   # select a.title, a.rank from autocomplete a
  #   # inner join docs d on d.id = a.rowid
  #   # inner join similarly_named sn on d.package = sn.package and sn.package_group = 'ecto'
  #   # inner join packages p on d.package = p.name and p.recent_downloads > 100000
  #   # where a.title match 'start link'
  #   # order by rank
  #   # limit 10;
  #   # """

  #   def build_per_package_fts do
  #     # "packages"
  #     # |> where([p], p.recent_downloads > 1_000_000)
  #     # |> select([p], p.name)
  #     # |> Repo.all()
  #     # |> Enum.each(fn package ->
  #     #   Repo.query!("drop table if exists #{package}_fts")
  #     # end)

  #     Repo.transaction(
  #       fn ->
  #         "packages"
  #         |> where([p], p.recent_downloads <= 2_500 and p.recent_downloads > 500)
  #         |> where([p], not like(p.name, "sqlite_%"))
  #         |> select([p], p.name)
  #         |> Repo.all()
  #         |> Enum.each(fn package ->
  #           Repo.query!("drop table if exists #{package}_fts")

  #           Repo.query!("""
  #           create virtual table #{package}_fts using fts5(
  #             title, doc,
  #             tokenize='porter', content='docs', content_rowid='id'
  #           )
  #           """)

  #           Repo.query!(
  #             """
  #             insert into #{package}_fts(rowid, title, doc) select id, title, doc from docs where package = ?
  #             """,
  #             [package],
  #             timeout: :infinity
  #           )

  #           Repo.query!("insert into #{package}_fts(#{package}_fts) values('optimize')")
  #         end)
  #       end,
  #       timeout: :infinity
  #     )

  #     Repo.query!("vacuum")
  #     Repo.query!("pragma wal_checkpoint(truncate)")
  #   end

  #   def build_wat2 do

  #     for file <- ["wat2.db", "wat2.db-wal", "wat2.db-shm"], do: File.rm(file)
  #     {:ok, db} = Sqlite3.open("wat2.db")

  #     try do
  #       :ok =
  #         Sqlite3.execute(db, """
  #         create table docs(
  #           id integer primary key,
  #           ref text not null,
  #           type text not null,
  #           title text not null,
  #           doc text not null
  #         ) strict
  #         """)

  #       :ok = Sqlite3.execute(db, "attach database 'wat_dev.db' as wat_dev")

  #       :ok =
  #         Sqlite3.execute(db, """
  #         insert into docs(id, ref, type, title, doc)
  #           select id, ref, type, title, doc from wat_dev.docs
  #         """)

  #       :ok = Sqlite3.execute(db, "begin")

  #       Repo.transaction(
  #         fn ->
  #           "packages"
  #           |> where([p], p.recent_downloads > 500)
  #           |> order_by(desc: :recent_downloads)
  #           |> select([p], map(p, [:name, :recent_downloads]))
  #           |> Repo.all()
  #           |> Enum.each(fn package ->
  #             IO.inspect(package.recent_downloads, label: package.name)
  #             table = "hexdocs_#{package.name}_fts"

  #             :ok =
  #               Sqlite3.execute(db, """
  #               create virtual table #{table} using fts5(title, doc, tokenize='porter', content='docs', content_rowid='id')
  #               """)

  #             :ok =
  #               Sqlite3.execute(
  #                 db,
  #                 """
  #                 insert into #{table}(rowid, title, doc) select id, title, doc from wat_dev.docs where package = '#{package.name}'
  #                 """
  #               )

  #             :ok =
  #               Sqlite3.execute(db, "insert into #{table}(#{table}) values('optimize')")
  #           end)
  #         end,
  #         timeout: :infinity
  #       )

  #       :ok = Sqlite3.execute(db, "commit")
  #       :ok = Sqlite3.execute(db, "vacuum")
  #       :ok = Sqlite3.execute(db, "pragma wal_checkpoint(truncate)")
  #     after
  #       Sqlite3.close(db)
  #     end
  #   end

  def extract_function(title) do
    title |> String.split(".") |> List.last()
  end

  defp extras_title(title) do
    case String.split(title, " - ") do
      [title] -> title
      parts -> Enum.drop(parts, -1)
    end
  end

  # defp extract_task(title) do
  #   if String.contains?(title, " - ") do
  #     title |> String.split(" - ") |> Enum.drop(-1)
  #   else
  #     case title do
  #       "Mix." <> _ ->
  #         ["mix", "tasks" | name] = title |> String.split(".") |> Enum.map(&Macro.underscore/1)
  #         Enum.join(name, " ")

  #       "mix " <> _ ->
  #         # ensure it's `mix <task>` and not something else
  #         ["mix", _task] = String.split(title, " ")
  #         title |> String.split(".") |> Enum.join(" ")
  #     end
  #   end
  # end

  # sqlite> select distinct type from docs;
  # ┌───────────────┐
  # │     type      │
  # ├───────────────┤
  # │ behaviour     │
  #  │ callback      │
  # │ exception     │
  # │ extras        │
  #  │ function      │
  #  │ macro         │
  #  │ macrocallback │
  # │ module        │
  #  │ opaque        │
  # │ protocol      │
  # │ task          │
  #  │ type          │
  # └───────────────┘

  def build_wat3 do
    {:ok, wat3} = Sqlite3.open("wat3.db")

    insert_sql = fn table, count ->
      IO.iodata_to_binary([
        "insert into #{table}(rowid, title, doc) values ",
        Enum.intersperse(List.duplicate("(?,?,?)", count), ?,)
      ])
    end

    try do
      :ok = Sqlite3.execute(wat3, "attach database 'wat_dev.db' as wat_dev")

      {:ok, rows} =
        Wat.query(
          wat3,
          "select name from wat_dev.packages where recent_downloads > 500 order by recent_downloads desc",
          [],
          _max_rows = 500
        )

      packages = Enum.map(rows, fn [package] -> package end)
      :ok = Sqlite3.execute(wat3, "begin")

      Enum.each(packages, fn package ->
        IO.puts(package)
        table = "hexdocs_#{package}_fts"

        :ok =
          Sqlite3.execute(wat3, """
          create virtual table #{table} using fts5(title, doc, tokenize='porter', content='docs', content_rowid='id')
          """)

        {:ok, rows} =
          Wat.query(
            wat3,
            "select id, title, doc, type from wat_dev.docs where package = ?",
            [package]
          )

        rows
        |> Enum.map(fn row ->
          [id, title, doc, type] = row

          title =
            case type do
              _
              when type in ["function", "callback", "macro", "macrocallback", "opaque", "type"] ->
                if String.contains?(title, " - ") do
                  extras_title(title)
                else
                  extract_function(title)
                end

              _
              when type in ["behaviour", "exception", "extras", "module", "protocol"] ->
                extras_title(title)

              "task" ->
                title
            end

          [id, title, doc]
        end)
        |> Enum.chunk_every(1000)
        |> Enum.each(fn rows ->
          {:ok, _} =
            Wat.query(
              wat3,
              insert_sql.(table, length(rows)),
              # flatten once
              Enum.flat_map(rows, &Function.identity/1)
            )
        end)

        :ok =
          Sqlite3.execute(wat3, "insert into #{table}(#{table}) values('optimize')")
      end)

      :ok = Sqlite3.execute(wat3, "commit")
      :ok = Sqlite3.execute(wat3, "vacuum")
      :ok = Sqlite3.execute(wat3, "pragma wal_checkpoint(truncate)")
    after
      Sqlite3.close(wat3)
    end
  end

  def build_wat4 do
    {:ok, wat4} = Sqlite3.open("wat4.db")

    try do
      :ok = Sqlite3.execute(wat4, "attach database 'wat_dev.db' as wat_dev")
      :ok = Sqlite3.execute(wat4, "begin")

      # TODO type score?
      :ok =
        Sqlite3.execute(
          wat4,
          "CREATE TABLE docs(id INTEGER PRIMARY KEY NOT NULL, ref TEXT NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL, doc TEXT NOT NULL) STRICT"
        )

      :ok =
        Sqlite3.execute(
          wat4,
          "insert into docs(id, ref, type, title, doc) select id, ref, type, title, doc from wat_dev.docs"
        )

      {:ok, rows} =
        Wat.query(
          wat4,
          "select name from wat_dev.packages where recent_downloads > 500 order by recent_downloads desc",
          [],
          _max_rows = 500
        )

      packages = Enum.map(rows, fn [package] -> package end)

      insert_sql = fn table, count ->
        IO.iodata_to_binary([
          "insert into #{table}(rowid, title, ref, type) values ",
          Enum.intersperse(List.duplicate("(?,?,?,?)", count), ?,)
        ])
      end

      # autocomplete
      Enum.each(packages, fn package ->
        IO.puts(package)
        table = "hexdocs_#{package}_autocomplete"

        :ok =
          Sqlite3.execute(wat4, """
          create virtual table #{table} using fts5(title, ref UNINDEXED, type UNINDEXED, tokenize='trigram', content='docs', content_rowid='id')
          """)

        {:ok, rows} =
          Wat.query(
            wat4,
            "select id, title, ref, type from wat_dev.docs where package = ?",
            [package]
          )

        rows
        |> Enum.map(fn row ->
          [id, title, ref, type] = row

          title =
            case type do
              _
              when type in ["function", "callback", "macro", "macrocallback", "opaque", "type"] ->
                if String.contains?(title, " - ") do
                  extras_title(title)
                else
                  extract_function(title)
                end

              _
              when type in ["behaviour", "exception", "extras", "module", "protocol"] ->
                extras_title(title)

              "task" ->
                title
            end

          [id, title, ref, type]
        end)
        |> Enum.chunk_every(1000)
        |> Enum.each(fn rows ->
          {:ok, _} =
            Wat.query(
              wat4,
              insert_sql.(table, length(rows)),
              # flatten once
              Enum.flat_map(rows, &Function.identity/1)
            )
        end)

        :ok =
          Sqlite3.execute(wat4, "insert into #{table}(#{table}) values('optimize')")
      end)

      insert_sql = fn table, count ->
        IO.iodata_to_binary([
          "insert into #{table}(rowid, title, doc, ref, type) values ",
          Enum.intersperse(List.duplicate("(?,?,?,?,?)", count), ?,)
        ])
      end

      # fts
      Enum.each(packages, fn package ->
        IO.puts(package)
        table = "hexdocs_#{package}_fts"

        :ok =
          Sqlite3.execute(wat4, """
          create virtual table #{table} using fts5(title, doc, ref UNINDEXED, type UNINDEXED, tokenize='porter', content='docs', content_rowid='id')
          """)

        {:ok, rows} =
          Wat.query(
            wat4,
            "select id, title, doc, ref, type from wat_dev.docs where package = ?",
            [package]
          )

        rows
        |> Enum.map(fn row ->
          [id, title, doc, ref, type] = row

          title =
            case type do
              _
              when type in ["function", "callback", "macro", "macrocallback", "opaque", "type"] ->
                if String.contains?(title, " - ") do
                  extras_title(title)
                else
                  extract_function(title)
                end

              _
              when type in ["behaviour", "exception", "extras", "module", "protocol"] ->
                extras_title(title)

              "task" ->
                title
            end

          [id, title, doc, ref, type]
        end)
        |> Enum.chunk_every(1000)
        |> Enum.each(fn rows ->
          {:ok, _} =
            Wat.query(
              wat4,
              insert_sql.(table, length(rows)),
              # flatten once
              Enum.flat_map(rows, &Function.identity/1)
            )
        end)

        :ok =
          Sqlite3.execute(wat4, "insert into #{table}(#{table}) values('optimize')")
      end)

      :ok = Sqlite3.execute(wat4, "commit")
      :ok = Sqlite3.execute(wat4, "pragma vacuum")
      :ok = Sqlite3.execute(wat4, "pragma optimize")
      :ok = Sqlite3.execute(wat4, "pragma wal_checkpoint(truncate)")
    after
      Sqlite3.close(wat4)
    end
  end

  # TODO wat5 spellfix for autocomplete?
end
