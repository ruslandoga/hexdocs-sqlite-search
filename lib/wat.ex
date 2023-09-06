defmodule Wat do
  @moduledoc """
  Wat keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  import Ecto.Query

  def api_fts(query, packages) do
    query = quote_query(query)
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
          score: selected_as(fragment("bm25(?, 100, 1)", literal(^table)), :score),
          excerpts: [fragment("snippet(?, 1, '<em>', '</em>', '...', 20)", literal(^table))]
        })
        |> limit(25)
        |> order_by([t], selected_as(:score))
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
