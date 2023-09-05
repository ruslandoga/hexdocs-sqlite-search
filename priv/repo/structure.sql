CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT);
CREATE TABLE IF NOT EXISTS "packages" ("name" TEXT NOT NULL PRIMARY KEY, "recent_downloads" INTEGER DEFAULT 0 NOT NULL) STRICT, WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "docs" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "package" TEXT NOT NULL CONSTRAINT "docs_package_fkey" REFERENCES "packages"("name"), "ref" TEXT NOT NULL, "type" TEXT NOT NULL, "title" TEXT NOT NULL, "embedding" BLOB, "doc" TEXT NOT NULL) STRICT;
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "packages_edges" ("source" TEXT, "target" TEXT, PRIMARY KEY ("source","target")) STRICT, WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'autocomplete_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'autocomplete_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'autocomplete_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'autocomplete_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "autocomplete_spellfix_vocab"(
  id INTEGER PRIMARY KEY,
  rank INT,
  langid INT,
  word TEXT,
  k1 TEXT,
  k2 TEXT
);
CREATE TABLE similarly_named(package text not null, package_group text not null) strict;
CREATE TABLE IF NOT EXISTS 'fts_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'fts_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'fts_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'fts_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE INDEX "docs_type_index" ON "docs" ("type");
CREATE UNIQUE INDEX "docs_package_ref_index" ON "docs" ("package", "ref");
CREATE INDEX "autocomplete_spellfix_vocab_index_langid_k2" ON "autocomplete_spellfix_vocab"(langid,k2);
CREATE INDEX similarly_named_package_index on similarly_named(package);
CREATE INDEX similarly_named_package_group_index on similarly_named(package_group);
CREATE INDEX packages_edges_source_target_index on packages_edges(source, target);
CREATE INDEX packages_recent_downloads_index on packages(recent_downloads desc)
;
CREATE VIRTUAL TABLE docs_vss using vss0(embedding(1536));
CREATE VIRTUAL TABLE autocomplete using fts5(
  title,
  tokenize='trigram', content='docs', content_rowid='id'
)
/* autocomplete(title) */;
CREATE VIRTUAL TABLE autocomplete_spellfix using spellfix1();
CREATE VIRTUAL TABLE fts using fts5(
  title, doc, package UNINDEXED,
  tokenize='porter', content='docs', content_rowid='id'
)
/* fts(title,doc,package) */;
INSERT INTO schema_migrations VALUES(20230818070639,'2023-08-18T09:42:30');
INSERT INTO schema_migrations VALUES(20230818090457,'2023-08-18T09:42:30');
INSERT INTO schema_migrations VALUES(20230818091119,'2023-08-19T12:11:25');
INSERT INTO schema_migrations VALUES(20230828102111,'2023-08-28T10:22:18');
