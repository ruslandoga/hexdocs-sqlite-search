defmodule WatTest do
  use ExUnit.Case, async: true

  describe "api_fts/2" do
    test "query w/o packages" do
      assert Wat.api_fts("query", []) == []
    end

    test "query w/ packages" do
      found = Wat.api_fts("query", ["ecto"])

      assert Enum.take(found, 3) == [
               %{
                 excerpts: [
                   "Provides the <em>Query</em> DSL.\n\n<em>Queries</em> are used to retrieve and manipulate data from a repository\n(see `Ecto.Repo`). Ecto <em>queries</em>..."
                 ],
                 package: "ecto",
                 rank: 2.3,
                 ref: "Ecto.Query.html",
                 title: "Ecto.Query",
                 type: "module"
               },
               %{
                 excerpts: [
                   "The `Ecto.<em>Query</em>` struct.\n\nUsers of Ecto must consider this struct as opaque\nand not access its field directly. Authors..."
                 ],
                 package: "ecto",
                 rank: 2.2,
                 ref: "Ecto.Query.html#__struct__/0",
                 title: "Ecto.Query.__struct__/0",
                 type: "function"
               },
               %{
                 type: "macro",
                 title: "Ecto.Query.distinct/3",
                 ref: "Ecto.Query.html#distinct/3",
                 package: "ecto",
                 excerpts: [
                   "A distinct <em>query</em> expression.\n\nWhen true, only keeps distinct values from the resulting\nselect expression.\n\nIf supported by your database..."
                 ],
                 rank: 2.2
               }
             ]
    end

    test "empty query" do
      assert Wat.api_fts("", ["ecto"]) == []
    end

    test "'transaction' in [ecto,ecto_sql,db_connection,ecto_ch,mint]" do
      found = Wat.api_fts("transaction", ["ecto", "ecto_sql", "db_connection"])

      assert Enum.take(found, 3) ==
               [
                 %{
                   excerpts: [
                     "Returns true if the current process is inside a <em>transaction</em>.\n\nIf you are using the `Ecto.Adapters.SQL.Sandbox` in..."
                   ],
                   package: "ecto",
                   ref: "Ecto.Repo.html#c:in_transaction?/0",
                   title: "Ecto.Repo.in_transaction?/0",
                   type: "callback",
                   rank: 2.2
                 },
                 %{
                   excerpts: [
                     "MyRepo.in_<em>transaction</em>?\n    #=> false\n\n    MyRepo.<em>transaction</em>(fn ->\n      MyRepo.in_<em>transaction</em>? #=> true\n    end)"
                   ],
                   package: "ecto",
                   ref: "Ecto.Repo.html#c:in_transaction?/0-examples",
                   title: "Examples - Ecto.Repo.in_transaction?/0",
                   type: "callback",
                   rank: 2.2
                 },
                 %{
                   excerpts: [
                     "Runs the given function or `Ecto.Multi` inside a <em>transaction</em>."
                   ],
                   package: "ecto",
                   ref: "Ecto.Repo.html#c:transaction/2",
                   title: "Ecto.Repo.transaction/2",
                   type: "callback",
                   rank: 2.2
                 }
               ]
    end

    test "'embed json' in [ecto,ecto_sql,db_connection,ecto_ch,mint]" do
      found = Wat.api_fts("embed json", ["ecto", "ecto_sql", "db_connection"])

      assert Enum.take(found, 3) ==
               [
                 %{
                   excerpts: [
                     "Casts the given <em>embed</em> with the changeset parameters.\n\nThe parameters for the given <em>embed</em> will be retrieved\nfrom `changeset.params..."
                   ],
                   package: "ecto",
                   rank: 2.2,
                   ref: "Ecto.Changeset.html#cast_embed/3",
                   title: "Ecto.Changeset.cast_embed/3",
                   type: "function"
                 },
                 %{
                   excerpts: [
                     "* `:required` - if the <em>embed</em> is a required field. For <em>embeds</em> of cardinality\n    one, a non-nil value satisfies this validation..."
                   ],
                   package: "ecto",
                   rank: 2.2,
                   ref: "Ecto.Changeset.html#cast_embed/3-options",
                   title: "Options - Ecto.Changeset.cast_embed/3",
                   type: "function"
                 },
                 %{
                   excerpts: [
                     "Gets the embedded entry or entries from changes or from the data.\n\nReturned data is normalized to changesets by default..."
                   ],
                   package: "ecto",
                   rank: 2.2,
                   ref: "Ecto.Changeset.html#get_embed/3",
                   title: "Ecto.Changeset.get_embed/3",
                   type: "function"
                 }
               ]
    end
  end
end
