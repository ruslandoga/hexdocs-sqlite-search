CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "packages" ("name" TEXT NOT NULL PRIMARY KEY, "recent_downloads" INTEGER DEFAULT 0 NOT NULL) STRICT, WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "docs" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "package" TEXT NOT NULL CONSTRAINT "docs_package_fkey" REFERENCES "packages"("name"), "ref" TEXT NOT NULL, "type" TEXT NOT NULL, "title" TEXT NOT NULL, "embedding" BLOB, "doc" TEXT NOT NULL) STRICT;
CREATE INDEX "docs_type_index" ON "docs" ("type");
CREATE UNIQUE INDEX "docs_package_ref_index" ON "docs" ("package", "ref");
CREATE VIRTUAL TABLE docs_title_fts using fts5(title, tokenize='trigram', content='docs', content_rowid='id')
/* docs_title_fts(title) */;
CREATE TABLE IF NOT EXISTS 'docs_title_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'docs_title_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'docs_title_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'docs_title_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE VIRTUAL TABLE docs_doc_fts using fts5(doc, content='docs', content_rowid='id')
/* docs_doc_fts(doc) */;
CREATE TABLE IF NOT EXISTS 'docs_doc_fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'docs_doc_fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'docs_doc_fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'docs_doc_fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
INSERT INTO schema_migrations VALUES(20230818070639,'2023-08-18T09:42:30');
INSERT INTO schema_migrations VALUES(20230818090457,'2023-08-18T09:42:30');
INSERT INTO schema_migrations VALUES(20230818091119,'2023-08-19T12:11:25');
