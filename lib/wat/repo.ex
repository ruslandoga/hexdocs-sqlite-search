defmodule Wat.Repo do
  use Ecto.Repo,
    otp_app: :wat,
    adapter: Ecto.Adapters.SQLite3
end
