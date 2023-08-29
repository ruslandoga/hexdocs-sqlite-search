defmodule Wat.Repo.Migrations.AddEdges do
  use Ecto.Migration

  def change do
    create table(:packages_edges, primary_key: false, options: "STRICT, WITHOUT ROWID") do
      add :source, :text, primary_key: true
      add :target, :text, primary_key: true
    end
  end
end
