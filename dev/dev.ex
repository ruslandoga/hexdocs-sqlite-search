defmodule Dev do
  require Logger
  import Ecto.Query
  alias Wat.Repo

  def doku_path do
    Path.expand("../doku")
  end

  def populate_packages do
    prefix = Path.join(doku_path(), "stats")

    prefix
    |> File.ls!()
    |> Enum.map(fn file ->
      name = String.trim_trailing(file, ".json")
      stats = prefix |> Path.join(file) |> File.read!() |> Jason.decode!()
      recent_downloads = get_in(stats, ["downloads", "recent"]) || 0
      %{"name" => name, "recent_downloads" => recent_downloads}
    end)
    |> Enum.chunk_every(1000)
    |> Enum.each(fn packages ->
      Repo.insert_all("packages", packages,
        log: false,
        on_conflict: {:replace, [:recent_downloads]}
      )
    end)
  end

  def populate_docs do
    prefix = Path.join(doku_path(), "index")

    # max_recent_downloads = ("packages" |> select([p], max(p.recent_downloads)) |> Wat.Repo.one)
    # Wat.Repo.insert_all("packages", Enum.map(["elixir", "eex", "ex_unit", "iex", "logger", "mix"], &%{name: &1, recent_downloads: 5_000_000}))
    # Enum.map(["elixir", "eex", "ex_unit", "iex", "logger", "mix"], fn n -> n <> ".json" end)

    prefix
    |> File.ls!()
    |> Enum.each(fn file ->
      package = String.trim_trailing(file, ".json")
      Logger.debug("importing #{package}")

      Path.join(prefix, file)
      |> read_docs_items()
      |> Enum.map(fn item ->
        Map.take(item, ["ref", "title", "type", "doc"])
        |> Map.update!("type", fn type -> type || "extras" end)
        |> Map.put("package", package)
      end)
      |> Enum.chunk_every(1000)
      |> Enum.each(fn docs ->
        Repo.insert_all("docs", docs,
          log: false,
          on_conflict: {:replace, [:title, :type, :doc]}
        )
      end)
    end)
  end

  # sqlite> select distinct type from docs;
  # ┌───────────────┐
  # │     type      │
  # ├───────────────┤
  # │ behaviour     │
  # │ callback      │
  # │ exception     │
  # │ extras        │
  # │ function      │
  # │ macro         │
  # │ macrocallback │
  # │ module        │
  # │ opaque        │
  # │ protocol      │
  # │ task          │
  # │ type          │
  # └───────────────┘

  def populate_autocomplete do
    Repo.transaction(fn ->
      Repo.query!("drop table if exists autocomplete")

      Repo.query!("""
      create virtual table autocomplete using fts5(
        title,
        tokenize='trigram', content='docs', content_rowid='id'
      )
      """)

      populate_autocomplete_behaviour()
      populate_autocomplete_callback()
      populate_autocomplete_exception()
      populate_autocomplete_extras()
      populate_autocomplete_function()
      populate_autocomplete_macro()
      populate_autocomplete_macrocallback()
      populate_autocomplete_module()
      populate_autocomplete_opaque()
      populate_autocomplete_protocol()
      populate_autocomplete_task()
      populate_autocomplete_type()
    end)
  end

  def populate_autocomplete_behaviour do
    Repo.query!(
      """
      insert into autocomplete(rowid, title)
        select id, title from docs
          where type = 'behaviour' and instr(title, ' ') = 0
      """,
      timeout: :infinity
    )
  end

  def populate_autocomplete_callback do
    "docs"
    |> where(type: "callback")
    |> where([d], fragment("instr(?, ' ')", d.title) == 0)
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_function/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_exception do
    Repo.query!("""
    insert into autocomplete(rowid, title)
      select id, title from docs
        where type = 'exception' and instr(title, ' ') = 0
    """)
  end

  def populate_autocomplete_extras do
    "docs"
    |> where(type: "extras")
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extras_title/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_function do
    "docs"
    |> where(type: "function")
    |> where([d], fragment("instr(?, ' ')", d.title) == 0)
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_function/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_macro do
    "docs"
    |> where(type: "macro")
    |> where([d], fragment("instr(?, ' ')", d.title) == 0)
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_function/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_macrocallback do
    "docs"
    |> where(type: "macrocallback")
    |> where([d], fragment("instr(?, ' ')", d.title) == 0)
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_function/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_module do
    "docs"
    |> where(type: "module")
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extras_title/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_opaque do
    "docs"
    |> where(type: "opaque")
    |> where([d], fragment("instr(?, ' ')", d.title) == 0)
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_function/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_protocol do
    "docs"
    |> where(type: "protocol")
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extras_title/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_task do
    "docs"
    |> where(type: "task")
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_task/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  def populate_autocomplete_type do
    "docs"
    |> where(type: "type")
    |> where([d], fragment("instr(?, ' ')", d.title) == 0)
    |> select([d], %{rowid: d.id, title: d.title})
    |> Repo.stream(max_rows: 1000)
    |> Stream.map(fn doc -> Map.update!(doc, :title, &extract_function/1) end)
    |> Stream.chunk_every(1000)
    |> Enum.each(&Repo.insert_all("autocomplete", &1))
  end

  defp extras_title(title) do
    case String.split(title, " - ") do
      [title] -> title
      parts -> Enum.drop(parts, -1)
    end
  end

  defp extract_function(title) do
    title |> String.split(".") |> List.last()
  end

  defp extract_task(title) do
    if String.contains?(title, " - ") do
      title |> String.split(" - ") |> Enum.drop(-1)
    else
      case title do
        "Mix." <> _ ->
          ["mix", "tasks" | name] = title |> String.split(".") |> Enum.map(&Macro.underscore/1)
          "mix " <> Enum.join(name, ".")

        "mix " <> _ ->
          # ensure it's `mix <task>` and not something else
          ["mix", _task] = String.split(title, " ")
          title
      end
    end
  end

  # def populate_docs_title_fts do
  #   Repo.query(
  #     """
  #     insert into docs_title_fts(rowid, title)
  #       select id, title from docs
  #       where instr(title, ' ') > 0 and type in ('function');
  #     """,
  #     timeout: :infinity
  #   )

  #   Repo.transaction(fn ->
  #     "docs"
  #     |> select([d], map(d, [:id, :title, :type]))
  #     |> where([d], d.type in ["macro", "callback", "behaviour"])
  #     |> Repo.stream(max_rows: 1000)
  #     |> Stream.chunk_every(1000)
  #     |> Stream.each(fn chunk ->
  #       indexable =
  #         chunk
  #         |> Enum.map(fn doc ->
  #           case doc.type do
  #             "task" ->
  #               %{id: id, title: title_for_search(title)}

  #             t when t in ["macro", "callback"] ->
  #               if String.contains?(doc.title, " ") do
  #                 Map.take(doc, [:id, :title])
  #               end

  #             _other ->
  #               Map.take(doc, [:id, :title])
  #           end
  #         end)
  #         |> Enum.reject(&is_nil/1)

  #       Repo.insert_all("docs_title_fts", indexable)
  #     end)
  #     |> Stream.run()
  #   end)
  # end

  # def populate_docs_doc_fts do
  # end

  def populate_embeddings do
    {:ok, sup} = Task.Supervisor.start_link()

    "docs"
    |> join(:inner, [d], p in "packages", on: d.package == p.name)
    |> where([_, p], p.recent_downloads > 1_000_000 or p.name in ["ch", "ecto_ch"])
    |> where([d], d.doc != "##")
    # |> where(type: "extras")
    |> where([d], is_nil(d.embedding))
    |> limit(100)
    |> select([d], map(d, [:id, :doc]))
    |> Repo.all()
    |> populate_embeddings_continue(sup)
  end

  defp populate_embeddings_continue([], sup) do
    :ok = Supervisor.stop(sup)
  end

  defp populate_embeddings_continue(docs, sup) do
    Task.Supervisor.async_stream_nolink(
      sup,
      docs,
      fn %{id: id, doc: doc} ->
        IO.inspect(id)
        populate_embedding(id, doc)
      end,
      max_concurrency: 100,
      ordered: false,
      timeout: :timer.seconds(10)
    )
    |> Stream.run()

    populate_embeddings()
  end

  def populate_embedding(id, doc) do
    Wat.update_embedding(id, OpenAI.embedding(doc))
  end

  def read_docs_items(file) do
    json = File.read!(file)

    docs =
      case Jason.decode(json) do
        {:ok, docs} ->
          docs

        {:error, %Jason.DecodeError{}} ->
          fixed_json = fix_json(json)

          case Jason.decode(fixed_json) do
            {:ok, docs} ->
              docs

            {:error, %Jason.DecodeError{position: position} = error} ->
              Logger.error(file: file, section: binary_slice(fixed_json, position - 10, 20))
              raise error
          end
      end

    case docs do
      %{"items" => items} -> items
      items when is_list(items) -> items
    end
  end

  # https://github.com/elixir-lang/ex_doc/commit/60dfb4537549e551750bc9cd84610fb475f66acd
  defp fix_json(json) do
    json
    # |> String.replace("\\#\{", "\#{")
    |> to_json_string(<<>>)
  end

  # [file: "monad_cps.json", section: "gt;&gt;= \\a -&gt; Mo"]
  defp to_json_string(<<" \\a", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "a">>)

  # [file: "figlet.json", section: "en: flf2a\\d 4 3 8 15"]
  defp to_json_string(<<"\\d", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "d">>)

  # [file: "phoenix.json", section: "lo_dev=# \\d List of "]
  defp to_json_string(<<"\\\\d", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "d">>)

  # [file: "puid.json", section: "VWXYZ[]^_\\abcdefghij"]
  defp to_json_string(<<"_\\a", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "_a">>)

  # [file: "fluminus.json", section: "of nusstu\\e0123456)."]

  defp to_json_string(<<"u\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "ue">>)

  # [file: "boxen.json", section: "t; &quot;\\e[31m&quot"]
  defp to_json_string(<<";\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, ";e">>)

  # [file: "boxen.json", section: "4mhello, \\e[36melixi"]
  defp to_json_string(<<", \\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, ", e">>)

  # [file: "boxen.json", section: "36melixir\\e[0m&quot;"]
  defp to_json_string(<<"r\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "re">>)

  # [file: "chi2fit.json", section: "2fit.Fit \\e [ 0 m \\e"]
  defp to_json_string(<<" \\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, " e">>)

  # [file: "chi2fit.json", section: "ic Errors\\e[0m e [ 0"]
  defp to_json_string(<<"s\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "se">>)

  #  [file: "chi2fit.json", section: "formation\\e[0m e [ 0"]
  defp to_json_string(<<"n\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "ne">>)

  # [file: "owl.json", section: "36m┌─\\e[31mRed!\\"]
  defp to_json_string(<<"┌─\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "┌─e">>)

  # [file: "ex_unit_release.json", section: "ot;e[32m.\\e[0m Finis"]
  defp to_json_string(<<".\\e", rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, ".e">>)

  # [file: "cassandrax.json", section: "\"},{\"doc\":<<65, 32, "]
  defp to_json_string(<<"\"doc\":<<", rest::bytes>>, acc),
    do: to_json_string(rest, <<acc::bytes, "\"doc\":\"<<">>)

  # [file: "cassandrax.json", section: "2, ...>>,\"ref\":\"Cass"]
  defp to_json_string(<<">>,\"", rest::bytes>>, acc),
    do: to_json_string(rest, <<acc::bytes, ">>\",\"">>)

  # [file: "ecto.json", section: "ength, \\\"\\\#{Keyword."]
  defp to_json_string(<<"\\\#{", rest::bytes>>, acc),
    do: to_json_string(rest, <<acc::bytes, "\#{">>)

  defp to_json_string(<<?\b, rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "\\b">>)

  defp to_json_string(<<?\t, rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "\\t">>)

  defp to_json_string(<<?\n, rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "\\n">>)

  defp to_json_string(<<?\f, rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "\\f">>)

  defp to_json_string(<<?\r, rest::binary>>, acc),
    do: to_json_string(rest, <<acc::binary, "\\r">>)

  defp to_json_string(<<x, rest::binary>>, acc) when x <= 0x000F,
    do: to_json_string(rest, <<acc::binary, "\\u000#{Integer.to_string(x, 16)}">>)

  defp to_json_string(<<x, rest::binary>>, acc) when x <= 0x001F,
    do: to_json_string(rest, <<acc::binary, "\\u00#{Integer.to_string(x, 16)}">>)

  defp to_json_string(<<x, rest::binary>>, acc), do: to_json_string(rest, <<acc::binary, x>>)
  defp to_json_string(<<>>, acc), do: acc

  def count_embeddings do
    "docs" |> where([d], not is_nil(d.embedding)) |> Repo.aggregate(:count)
  end

  def stream_embeddings(callback) when is_function(callback, 1) do
    Repo.transaction(
      fn ->
        "docs"
        |> where([d], not is_nil(d.embedding))
        |> select([d], map(d, [:id, :embedding]))
        |> Repo.stream()
        |> callback.()
      end,
      timeout: :infinity,
      max_rows: 1000
    )
  end

  def make_hnsw_index do
    with {:ok, index} <-
           HNSWLib.Index.new(_space = :cosine, _dim = 1536, _max_elements = count_embeddings()) do
      stream_embeddings(fn stream ->
        stream
        |> Stream.chunk_every(1000)
        |> Stream.each(fn chunk ->
          IO.puts("adding items...")
          tensor = chunk |> Enum.map(&Wat.decode_embedding(&1.embedding)) |> Nx.tensor(type: :f32)
          :ok = HNSWLib.Index.add_items(index, tensor, ids: Enum.map(chunk, & &1.id))
        end)
        |> Stream.run()

        index
      end)
    end
  end

  def list_similar_content(query) when is_binary(query) do
    query |> OpenAI.embedding() |> list_similar_content()
  end

  def list_similar_content(embedding) when is_list(embedding) do
    %HNSWLib.Index{} = index = :persistent_term.get(:hnsw)

    with {:ok, labels, dists} <-
           HNSWLib.Index.knn_query(index, Nx.tensor(embedding, type: :f32), k: 10) do
      [ids] = Nx.to_list(labels)
      [dists] = Nx.to_list(dists)

      docs =
        "docs"
        |> where([d], d.id in ^ids)
        |> select([d], map(d, [:id, :title, :ref, :package, :doc]))
        |> Repo.all()
        |> Map.new(fn %{id: id} = doc -> {id, doc} end)

      ids
      |> Enum.zip(dists)
      |> Enum.map(fn {id, dist} -> docs |> Map.fetch!(id) |> Map.put(:similarity, 1 - dist) end)
    end
  end
end
