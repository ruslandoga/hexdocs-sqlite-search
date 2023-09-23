queries = [
  "transaction",
  "json",
  "embed",
  "connect",
  "transact",
  "runtime",
  "dev",
  "config",
  "format",
  "upload",
  "allow",
  "controller",
  "view"
]

random_query = fn -> queries |> Enum.take_random(:rand.uniform(3)) |> Enum.join(" ") end

repos = ["ecto", "ecto_sql", "phoenix", "phoenix_live_view"]
random_repos = fn -> Enum.take_random(repos, :rand.uniform(5)) end

Benchee.run(%{
  # "api_fts/2" => fn -> Wat.api_fts(random_query.(), random_repos.()) end,
  # "api_autocomplete/2" => fn -> Wat.api_autocomplete(random_query.(), random_repos.()) end
  "spellfix" => fn ->
    Wat.query(
      Wat.db(),
      "select word from hexdocs_phoenix_live_view_spellfix where word match ? and top=3",
      [Enum.random(queries)]
    )
  end
})
