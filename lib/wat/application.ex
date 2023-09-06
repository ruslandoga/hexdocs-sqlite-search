defmodule Wat.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.fetch_env!(:wat, :port)
    server? = !!Application.get_env(:wat, :server)

    children = [
      {Task.Supervisor, name: Wat.Tasks},
      Wat.Repo,
      if server? do
        {Plug.Cowboy,
         scheme: :http, plug: Wat.Router, options: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port]}
      end
    ]

    children = Enum.reject(children, &is_nil/1)

    opts = [strategy: :one_for_one, name: Wat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
