defmodule Wat do
  @moduledoc """
  Wat keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  alias Exqlite.Sqlite3

  def start_db!(database) do
    {:ok, db} = Sqlite3.open(database, mode: :readonly)
    # :ets.new(:hexdocs_stmt_cache)
    :ok = Sqlite3.execute(db, "pragma cache_size=-64000")
    :ok = Sqlite3.enable_load_extension(db, true)
    ext_path = :filename.join(:code.priv_dir(:wat), ~c"hexdocs.so")
    {:ok, _} = query(db, "select load_extension(?)", [ext_path])
    :ok = :persistent_term.put(:hexdocs_db, db)
  end

  def db, do: :persistent_term.get(:hexdocs_db)

  def query(db, sql, args, max_rows \\ 50) do
    {:ok, stmt} = Sqlite3.prepare(db, sql)

    try do
      :ok = Sqlite3.bind(db, stmt, args)
      Sqlite3.fetch_all(db, stmt, max_rows)
    after
      Sqlite3.release(db, stmt)
    end
  end

  def api_fts(query, packages) do
    query = sanitize_query(query)

    if query == "" do
      []
    else
      # TODO whitelist packages
      db = db()

      Wat.Tasks
      |> Task.Supervisor.async_stream_nolink(
        packages,
        fn package ->
          table = "hexdocs_" <> package <> "_fts"

          sql = """
          select d.ref, d.type, f.title, snippet(#{table}, 1, '<em>', '</em>', '...', 20), hexdocs_rank(#{table}) \
          from #{table} f \
          inner join docs d on f.rowid = d.id \
          where #{table} match ? \
          order by 5 desc \
          limit 25\
          """

          {:ok, rows} = query(db, sql, [query])

          Enum.map(rows, fn row ->
            [ref, type, title, snippet, rank] = row

            boost =
              case type do
                "module" ->
                  if String.contains?(title, " ") do
                    0.1
                  else
                    0.2
                  end

                type when type in ["function", "callback", "macro"] ->
                  if String.contains?(title, " ") do
                    0.1
                  else
                    0.3
                  end

                "task" ->
                  0.1

                _other ->
                  0
              end

            %{
              ref: ref,
              type: type,
              title: title,
              excerpts: [snippet],
              rank: rank + boost,
              package: package
            }
          end)
        end,
        # ordered: false,
        max_concurrency: 3
      )
      |> Enum.flat_map(fn result ->
        case result do
          {:ok, docs} -> docs
          {:exit, _reason} -> []
        end
      end)
      |> Enum.sort_by(& &1.rank, :desc)
    end
  end

  # TODO
  # Use WORD^NUMBER (such as foo^2) to boost the given word
  # Use WORD~NUMBER (such as foo~2) to do a search with edit distance on word

  @doc false
  def sanitize_query(query) do
    query
    |> String.split(" ", trim: true)
    |> sanitize_segments(_required = [], _absent = [], _optional = [])
  end

  defp sanitize_segments([segment | segments], required, absent, optional) do
    case segment do
      "-" <> segment ->
        sanitize_segments(segments, required, ["NOT " <> sanitize(segment) | absent], optional)

      "+" <> segment ->
        sanitize_segments(segments, [sanitize(segment) | required], absent, optional)

      segment ->
        sanitize_segments(segments, required, absent, [sanitize(segment) | optional])
    end
  end

  defp sanitize_segments([], required, absent, optional) do
    join_segments(required, absent, optional)
  end

  defp join_segments([], [], [_ | _] = optional), do: Enum.join(optional, " OR ")
  defp join_segments([_ | _] = required, [], []), do: Enum.join(required, " AND ")

  defp join_segments([_ | _] = required, [], [_ | _] = optional) do
    "(" <> Enum.join(optional, " OR ") <> ") AND " <> Enum.join(required, " AND ")
  end

  defp join_segments([], [_ | _] = absent, [_ | _] = optional) do
    "(" <> Enum.join(optional, " OR ") <> ") " <> " " <> Enum.join(absent, " ")
  end

  defp join_segments([_ | _] = required, [_ | _] = absent, [_ | _] = optional) do
    "(" <>
      Enum.join(optional, " OR ") <>
      ") AND " <> Enum.join(required, " AND ") <> " " <> Enum.join(absent, " ")
  end

  defp join_segments([_ | _] = required, [_ | _] = absent, []) do
    Enum.join(required, " AND ") <> " " <> Enum.join(absent, " ")
  end

  defp join_segments([], [], []), do: ""
  defp join_segments([], [_ | _] = _absent, []), do: ""

  defp sanitize(segment) do
    if String.ends_with?(segment, "*") do
      (segment |> String.replace("*", "") |> quote_segment()) <> "*"
    else
      segment |> String.replace("*", "") |> quote_segment()
    end
  end

  defp quote_segment("" = empty), do: empty

  defp quote_segment("title:" <> segment) do
    ~s[title:] <> quote_segment(segment)
  end

  defp quote_segment("doc:" <> segment) do
    ~s[doc:] <> quote_segment(segment)
  end

  defp quote_segment(segment) do
    ~s["] <> String.replace(segment, ~s["], ~s[""]) <> ~s["]
  end

  def api_autocomplete(query, packages) do
    query = sanitize_query(query)

    if query == "" do
      []
    else
      db = db()

      Wat.Tasks
      |> Task.Supervisor.async_stream_nolink(
        packages,
        fn package ->
          table = "hexdocs_" <> package <> "_fts"

          sql = """
          select f.title \
          from #{table} f \
          where title match ? \
          limit 3\
          """

          {:ok, rows} = query(db, sql, [query])

          Enum.map(rows, fn row ->
            [title] = row
            %{title: title, package: package}
          end)
        end,
        # ordered: false,
        max_concurrency: 3
      )
      |> Enum.flat_map(fn result ->
        case result do
          {:ok, docs} -> docs
          {:exit, _reason} -> []
        end
      end)
    end
  end
end
