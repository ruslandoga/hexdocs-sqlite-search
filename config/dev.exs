import Config

# Configure your database
config :wat, database: Path.expand("../wat2.db", Path.dirname(__ENV__.file))