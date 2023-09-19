import Config

# Configure your database
config :wat, Wat.Repo,
  database: Path.expand("../wat2.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Print only warnings and errors during test
config :logger, level: :warning
