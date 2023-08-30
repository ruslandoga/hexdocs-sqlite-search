defmodule Wat.Repo.Migrations.AddDocsFts do
  use Ecto.Migration

  def change do
    execute """
            create virtual table autocomplete using fts5(title, tokenize='trigram', content='docs', content_rowid='id')
            """,
            """
            drop table if exists autocomplete
            """

    execute """
            create virtual table fts using fts5(title, doc, tokenize='porter', content='docs', content_rowid='id')
            """,
            """
            drop table if exists fts
            """

    execute "insert into fts(fts, rank) values('rank', 'bm25(20, 1)')"
  end
end
