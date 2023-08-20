defmodule OpenAI do
  @moduledoc "Basic OpenAI client"
  alias __MODULE__.API

  def embedding(input) do
    %Finch.Response{status: 200, body: body} =
      API.post!("/v1/embeddings", %{"input" => input, "model" => "text-embedding-ada-002"})

    %{"data" => [%{"embedding" => embedding}]} = Jason.decode!(body)
    embedding
  end
end
