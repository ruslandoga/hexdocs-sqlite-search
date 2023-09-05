defmodule WatWeb.SearchController do
  use WatWeb, :controller

  def search(conn, params) do
    query = params["q"]

    results =
      cond do
        query && (String.trim(query) == "" or byte_size(query) <= 2) ->
          []

        query ->
          %{query: query, packages: packages, anchor: _anchor} = Wat.parse_query(query)
          Wat.api_fts(query, packages)

        true ->
          []
      end

    json(conn, %{"results" => results})
  end
end
