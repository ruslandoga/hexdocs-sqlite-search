defmodule Wat.Router do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug Corsica, origins: ["https://hexdocs.pm", "null"]
  plug :match
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  get "/v0/search", do: search(conn)
  get "/v0/autocomplete", do: autocomplete(conn)

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def search(%{query_params: query_params} = conn) do
    query = query_params["q"]
    packages = packages(query_params["packages"])
    results = Wat.api_fts(query, packages)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode_to_iodata!(%{"results" => results}))
  end

  def autocomplete(%{query_params: query_params} = conn) do
    query = query_params["q"]
    packages = packages(query_params["packages"])
    results = Wat.api_autocomplete(query, packages)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode_to_iodata!(%{"results" => results}))
  end

  defp packages(packages) when is_list(packages), do: packages
  defp packages(packages) when is_binary(packages), do: String.split(packages, ",")
  defp packages(nil), do: []
end
