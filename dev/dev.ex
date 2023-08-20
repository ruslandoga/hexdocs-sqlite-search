defmodule Dev do
  require Logger

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
      Wat.Repo.insert_all("packages", packages,
        log: false,
        on_conflict: {:replace, [:recent_downloads]}
      )
    end)
  end

  def populate_docs do
    prefix = Path.join(doku_path(), "index")

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
        Wat.Repo.insert_all("docs", docs,
          log: false,
          on_conflict: {:replace, [:title, :type, :doc]}
        )
      end)
    end)
  end

  def populate_embeddings do
    import Ecto.Query

    {:ok, sup} = Task.Supervisor.start_link()

    "docs"
    |> join(:left, [d], p in "packages", on: d.package == p.name)
    |> where([_, p], p.recent_downloads > 1_000_000)
    # |> where(type: "extras")
    |> where([d], is_nil(d.embedding))
    |> limit(100)
    |> select([d], map(d, [:id, :doc]))
    |> Wat.Repo.all()
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
end
