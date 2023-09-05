defmodule WatWeb.SearchController do
  use WatWeb, :controller

  def search(conn, params) do
    query = params["q"]

    packages =
      case params["packages"] do
        packages when is_list(packages) -> packages
        packages when is_binary(packages) -> String.split(packages, ",")
        nil -> []
      end

    results =
      cond do
        query && (String.trim(query) == "" or byte_size(query) <= 2) ->
          []

        query ->
          Wat.api_fts(query, packages)

        true ->
          []
      end

    json(conn, %{"results" => results})
  end
end
