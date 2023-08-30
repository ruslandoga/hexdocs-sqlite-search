import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/wat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :wat, WatWeb.Endpoint, server: true
end

config :wat, Wat.Repo,
  # busy_timeout: :timer.seconds(5),
  cache_size: -2000

config :wat, Wat.Repo,
  after_connect: fn _conn ->
    [db_conn] = Process.get(:"$callers")
    {:no_state, %{state: %Exqlite.Connection{} = conn}} = :sys.get_state(db_conn)
    :ok = Exqlite.Basic.enable_load_extension(conn)
    Exqlite.Basic.load_extension(conn, ExSqlean.path_for("spellfix"))
  end

if config_env() == :prod do
  database_path = System.get_env("DATABASE_PATH") || "/app/wat.db"

  config :wat, Wat.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :wat, WatWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

if config_env() in [:dev, :prod] do
  config :wat, openai_api_key: System.fetch_env!("OPENAI_API_KEY")
end
