defmodule Wat.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    port = Application.fetch_env!(:wat, :port)
    server? = !!Application.get_env(:wat, :server)
    database = Application.fetch_env!(:wat, :database)

    Wat.start_db!(database)

    children = [
      {Task.Supervisor, name: Wat.Tasks},
      if server? do
        {Plug.Cowboy,
         scheme: :http, plug: Wat.Router, options: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port]}
      end
    ]

    children = Enum.reject(children, &is_nil/1)
    Supervisor.start_link(children, strategy: :one_for_one, name: Wat.Supervisor)
  end
end
