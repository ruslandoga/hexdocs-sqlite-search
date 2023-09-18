defmodule Wat do
  @moduledoc """
  Wat keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  import Ecto.Query

  def api_fts(query, packages) do
    query = sanitize_query(query)
    # TODO whitelist packages

    Wat.Tasks
    |> Task.Supervisor.async_stream_nolink(
      packages,
      fn package ->
        table = "hexdocs_" <> package <> "_fts"

        table
        |> where([t], fragment("? match ?", literal(^table), ^query))
        |> join(:inner, [t], d in "docs", on: t.rowid == d.id)
        |> select([t, d], %{
          ref: d.ref,
          type: d.type,
          title: t.title,
          excerpts: [fragment("snippet(?, 1, '<em>', '</em>', '...', 20)", literal(^table))]
        })
        |> limit(25)
        |> order_by([t, d], desc: fragment("hexdocs_rank(?, ?)", literal(^table), d.type))
        |> Wat.Repo.all()
        |> Enum.map(&Map.put(&1, :package, package))
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
