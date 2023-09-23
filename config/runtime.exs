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
# by passing the WAT_SERVER=true when you start it:
#
#     WAT_SERVER=true bin/wat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

default_db =
  case config_env() do
    :prod -> "/app/wat.db"
    _env -> Path.expand("../wat4.db", Path.dirname(__ENV__.file))
  end

config :wat,
  server: !!System.get_env("WAT_SERVER"),
  port: String.to_integer(System.get_env("WAT_SERVER_PORT") || "4000"),
  database: System.get_env("WAT_DATABASE_PATH") || default_db

default_log_level =
  case config_env() do
    env when env in [:prod, :bench, :test] -> :warning
    _env -> :debug
  end

log_level =
  if log_level = System.get_env("WAT_LOG_LEVEL") do
    String.to_existing_atom(log_level)
  end

config :logger, level: log_level || default_log_level
