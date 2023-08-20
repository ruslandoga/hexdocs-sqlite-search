defmodule Wat.Repo.Migrations.AddDocsFts do
  use Ecto.Migration

  def change do
    execute """
            create virtual table docs_title_fts using fts5(title, tokenize='trigram', content='docs', content_rowid='id')
            """,
            """
            drop table if exists docs_title_fts
            """

    execute """
            create virtual table docs_doc_fts using fts5(doc, content='docs', content_rowid='id')
            """,
            """
            drop table if exists docs_doc_fts
            """
  end
end
