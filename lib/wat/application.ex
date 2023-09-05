defmodule Wat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      WatWeb.Telemetry,
      # Start the Ecto repository
      Wat.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Wat.PubSub},
      # Start Finch
      {Finch, name: Wat.Finch},
      # Start the Endpoint (http/https)
      WatWeb.Endpoint,
      # Start a worker by calling: Wat.Worker.start_link(arg)
      # {Wat.Worker, arg},
      {Task.Supervisor, name: Wat.Tasks}
    ]

    if File.exists?("hnsw.idx") do
      {:ok, index} = HNSWLib.Index.load_index(:cosine, 1536, "hnsw.idx")
      :ok = :persistent_term.put(:hnsw, index)
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
