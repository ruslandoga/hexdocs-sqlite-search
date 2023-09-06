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

if config_env() == :prod do
  config :wat, Wat.Repo, database: System.get_env("WAT_DATABASE_PATH") || "/app/wat.db"
end

config :wat,
  server: !!System.get_env("WAT_SERVER"),
  port: String.to_integer(System.get_env("WAT_SERVER_PORT") || "4000")

config :wat, Wat.Repo,
  cache_size: String.to_integer(System.get_env("WAT_DATABASE_CACHE_SIZE") || "-2000"),
  pool_size: String.to_integer(System.get_env("WAT_DATABASE_POOL_SIZE") || "3")
