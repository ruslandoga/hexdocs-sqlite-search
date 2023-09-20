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
    {:ok, _} = exec(db, "select load_extension(?)", [ext_path])
    :ok = :persistent_term.put(:hexdocs_db, db)
  end

  def db, do: :persistent_term.get(:hexdocs_db)

  def exec(db, sql, args) do
    {:ok, stmt} = Sqlite3.prepare(db, sql)

    try do
      :ok = Sqlite3.bind(db, stmt, args)
      Sqlite3.fetch_all(db, stmt, 50)
    after
      Sqlite3.release(db, stmt)
    end
  end

  def api_fts(query, packages) do
    query = sanitize_query(query)
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

        {:ok, rows} = exec(db, sql, [query])

        Enum.map(rows, fn row ->
          [ref, type, title, excerpts, rank] = row

          boost =
            case type do
              "module" ->
                if String.contains?(title, " ") do
                  0.1
                else
                  0.3
                end

              type when type in ["function", "callback", "macro"] ->
                if String.contains?(title, " ") do
                  0.1
                else
                  # function = title |> String.split(".") |> List.last()
                  # if String.starts_with?(function, ) do
                  #   0.35
                  # else
                  #   0.2
                  # end
                  0.2
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
            excerpts: excerpts,
            rank: rank + boost,
            package: package
          }
        end)
      end,
      ordered: false,
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

  # TODO
  # Use WORD^NUMBER (such as foo^2) to boost the given word
  # Use WORD~NUMBER (such as foo~2) to do a search with edit distance on word

  @doc false
  def sanitize_query(query) do
    query
    |> String.split(" ")
    |> sanitize_segments(_required = [], _absent = [], _optional = [])
  end

  defp sanitize_segments([segment | segments], required, absent, optional) do
    case segment do
      "-" <> segment ->
        sanitize_segments(segments, required, ["-" <> sanitize(segment) | absent], optional)

      "+" <> segment ->
        sanitize_segments(segments, [sanitize(segment) | required], absent, optional)

      segment ->
        sanitize_segments(segments, required, absent, [sanitize(segment) | optional])
    end
  end

  defp sanitize_segments([], required, absent, optional) do
    or_group = Enum.join(optional, " OR ")
    and_group = Enum.join(absent ++ required, " AND ")

    case and_group do
      "" -> or_group
      _ -> "(" <> or_group <> ") AND " <> and_group
    end
  end

  defp sanitize(segment) do
    segment
    |> String.split("*")
    |> Enum.map(&quote_segment/1)
    |> Enum.join("*")
  end

  defp quote_segment("" = empty), do: empty

  defp quote_segment(segment) do
    ~s["] <> String.replace(segment, ~s["], ~s[""]) <> ~s["]
  end
end
