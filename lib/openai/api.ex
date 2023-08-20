defmodule OpenAI.API do
  @moduledoc false

  defp url(path), do: Path.join("https://api.openai.com", path)

  defp headers do
    [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{Wat.openai_api_key()}"}
    ]
  end

  def get!(path, opts \\ []) do
    req = Finch.build("GET", url(path), headers())
    Finch.request!(req, Wat.Finch, opts)
  end

  def post!(path, params, opts \\ []) do
    body = Jason.encode_to_iodata!(params)
    req = Finch.build("POST", url(path), headers(), body)
    Finch.request!(req, Wat.Finch, opts)
  end

  # def stream(path, params, callback, opts \\ []) do
  #   body = Jason.encode_to_iodata!(params)
  #   req = Finch.build("POST", url(path), headers(), body)

  #   f = fn packet, acc ->
  #     case packet do
  #       {:status, status} ->
  #         %Finch.Response{acc | status: status}

  #       {:headers, headers} ->
  #         %Finch.Response{acc | headers: headers}

  #       {:data, data} ->
  #         new =
  #           data
  #           |> String.split("\n\n")
  #           |> Enum.map(fn
  #             "data: [DONE]" <> _ ->
  #               []

  #             "data: " <> json ->
  #               json = Jason.decode!(json)
  #               tokens = get_in(json, ["choices", Access.all(), "delta", "content"])
  #               tokens |> Enum.reject(&is_nil/1) |> IO.iodata_to_binary()

  #             "" = empty ->
  #               empty
  #           end)

  #         body = IO.iodata_to_binary([acc.body | new])
  #         callback.(body)
  #         %Finch.Response{acc | body: body}
  #     end
  #   end

  #   Finch.stream(req, Wat.Finch, %Finch.Response{}, f, opts)
  # end
end
