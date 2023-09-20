import Config

# Configure your database
config :wat, database: Path.expand("../wat2.db", Path.dirname(__ENV__.file))

# Print only warnings and errors during test
config :logger, level: :warning
