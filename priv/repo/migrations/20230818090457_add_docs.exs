defmodule Wat.Repo.Migrations.AddDocs do
  use Ecto.Migration

  def change do
    create table(:docs, options: "STRICT") do
      add :package, references(:packages, type: :text, column: :name), null: false
      add :ref, :text, null: false
      add :type, :text, null: false
      add :title, :text, null: false
      add :embedding, :blob
      add :doc, :text, null: false
    end

    create index(:docs, [:type])
    create unique_index(:docs, [:package, :ref])
  end
end
