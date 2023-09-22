defmodule WatTest do
  use ExUnit.Case, async: true

  describe "api_fts/2" do
    test "query w/o packages" do
      assert Wat.api_fts("query", []) == []
    end

    test "query w/ packages" do
      found = Wat.api_fts("query", ["ecto"])

      assert take_titles(found) == [
               "Ecto.Query.put_query_prefix/2",
               "Ecto.Repo.prepare_query/3",
               "Ecto.Queryable.to_query/1",
               "Ecto.Adapter.Queryable.plan_query/3",
               "Ecto.Adapter.Queryable.prepare_query/3",
               "Ecto.Association.ManyToMany.assoc_query/2",
               "Ecto.Query",
               "Ecto.Query.API",
               "Ecto.Query.WindowAPI",
               "Query - Ecto"
             ]
    end

    test "empty query" do
      assert Wat.api_fts("", ["ecto"]) == []
    end

    test "'transaction'" do
      found = Wat.api_fts("transaction", ["ecto", "ecto_sql", "db_connection"])

      assert take_titles(found) == [
               "Ecto.Repo.in_transaction?/0",
               "Ecto.Repo.transaction/2",
               "Ecto.Adapter.Transaction.in_transaction?/1",
               "Ecto.Adapter.Transaction.transaction/3",
               "Ecto.Adapter.Migration.supports_ddl_transaction?/0",
               "DBConnection.transaction/3",
               "Nested transactions - Ecto.Repo.transaction/2",
               "Aborted transactions - Ecto.Repo.transaction/2",
               "Ecto.Adapter.Transaction",
               "Composable transactions with Multi"
             ]
    end

    test "'embed json'" do
      found =
        Wat.api_fts("embed json", [
          "ecto",
          "ecto_sql",
          "db_connection",
          "phoenix",
          "plug",
          "phoenix_live_view"
        ])

      assert take_titles(found) == [
               "Ecto.Changeset.cast_embed/3",
               "Ecto.Changeset.get_embed/3",
               "Ecto.Changeset.put_embed/4",
               "Ecto.Schema.embeds_many/3",
               "Ecto.Schema.embeds_many/4",
               "Ecto.Schema.embeds_one/3",
               "Ecto.Schema.embeds_one/4",
               "Ecto.ParameterizedType.embed_as/2",
               "Ecto.Type.embed_as/1",
               "Ecto.Type.embed_as/2"
             ]
    end

    test "returns all relevant fields" do
      found = Wat.api_fts("transaction", ["ecto", "ecto_sql", "db_connection"])

      assert hd(found) == %{
               type: "callback",
               title: "Ecto.Repo.in_transaction?/0",
               ref: "Ecto.Repo.html#c:in_transaction?/0",
               package: "ecto",
               rank: 2.3,
               excerpts: [
                 "Returns true if the current process is inside a <em>transaction</em>.\n\nIf you are using the `Ecto.Adapters.SQL.Sandbox` in..."
               ]
             }
    end

    test "-phrase operator" do
      assert Wat.api_fts("-embed", ["ecto"]) == []

      assert take_titles(Wat.api_fts("embed", ["ecto"])) == [
               "Ecto.Changeset.cast_embed/3",
               "Ecto.Changeset.get_embed/3",
               "Ecto.Changeset.put_embed/4",
               "Ecto.Schema.embeds_many/3",
               "Ecto.Schema.embeds_many/4",
               "Ecto.Schema.embeds_one/3",
               "Ecto.Schema.embeds_one/4",
               "Ecto.ParameterizedType.embed_as/2",
               "Ecto.Type.embed_as/1",
               "Ecto.Type.embed_as/2"
             ]

      assert take_titles(Wat.api_fts("embed -changeset", ["ecto"])) == [
               "Ecto.Schema.embeds_many/3",
               "Ecto.Schema.embeds_many/4",
               "Ecto.Schema.embeds_one/3",
               "Ecto.Schema.embeds_one/4",
               "Ecto.ParameterizedType.embed_as/2",
               "Ecto.Type.embed_as/1",
               "Ecto.Type.embed_as/2",
               "Ecto.UUID.embed_as/1",
               "Embeds - Ecto",
               "Embeds - Ecto.Enum"
             ]
    end

    test "+phrase operator" do
      assert Wat.api_fts("+embed", ["ecto"]) == Wat.api_fts("embed", ["ecto"])

      assert take_titles(Wat.api_fts("embed +changeset", ["ecto"])) == [
               "Ecto.Changeset.cast_embed/3",
               "Ecto.Changeset.get_embed/3",
               "Ecto.Changeset.put_embed/4",
               "Associations, embeds and on replace - Ecto.Changeset",
               "Embeds - Embedded Schemas",
               "Extracting the embeds - Embedded Schemas",
               "Changesets - Embedded Schemas",
               "Ecto.Changeset.change/2",
               "Ecto.Changeset.changed?/3",
               "Ecto.Changeset.get_change/3"
             ]
    end

    test "field:phrase operator" do
      assert take_titles(Wat.api_fts("embed +title:changeset", ["ecto"])) == [
               "Changesets - Embedded Schemas"
             ]
    end

    test "phras* operator" do
      assert take_titles(Wat.api_fts("tra*", ["ecto"])) == [
               "Ecto.Changeset.traverse_errors/2",
               "Ecto.Changeset.traverse_validations/2",
               "Ecto.Repo.in_transaction?/0",
               "Ecto.Repo.transaction/2",
               "Ecto.Adapter.Transaction.in_transaction?/1",
               "Ecto.Adapter.Transaction.transaction/3",
               "Nested transactions - Ecto.Repo.transaction/2",
               "Aborted transactions - Ecto.Repo.transaction/2",
               "Ecto.Adapter.Transaction",
               "Composable transactions with Multi"
             ]
    end
  end

  defp take_titles(docs, count \\ 10) do
    docs |> Enum.map(& &1.title) |> Enum.take(count)
  end
end
