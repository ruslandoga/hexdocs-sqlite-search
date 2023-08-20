defmodule Wat.Repo.Migrations.AddPackages do
  use Ecto.Migration

  def change do
    create table(:packages, primary_key: false, options: "STRICT, WITHOUT ROWID") do
      add :name, :text, primary_key: true, null: false
      add :recent_downloads, :integer, null: false, default: 0
    end
  end
end
