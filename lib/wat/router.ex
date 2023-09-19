defmodule Wat.Router do
  use Plug.Router
  require Logger

  plug Plug.Logger
  plug Corsica, origins: ["https://hexdocs.pm", "null"]
  plug :match
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  get "/v0/search", do: search(conn)

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def search(%{query_params: query_params} = conn) do
    query = query_params["q"]

    packages =
      case query_params["packages"] do
        packages when is_list(packages) -> packages
        packages when is_binary(packages) -> String.split(packages, ",")
        nil -> []
      end

    results = Wat.api_fts(query, packages)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode_to_iodata!(%{"results" => results}))
  end
end
