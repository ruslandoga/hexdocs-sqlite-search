import Config

config :logger, level: :warning

config :wat, database: Path.expand("../wat2.db", Path.dirname(__ENV__.file))
