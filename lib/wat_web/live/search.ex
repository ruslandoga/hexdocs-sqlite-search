defmodule WatWeb.SearchLive do
  use WatWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen">
      <form id="search-form" class="max-w-2xl mx-auto" phx-change="autocomplete" phx-submit="search">
        <input
          type="text"
          name="query"
          placeholder="Search..."
          value={@query}
          class="mt-4 w-full bg-zinc-100 border-zinc-300 dark:bg-zinc-500 dark:border-zinc-400"
          phx-debounce="50"
        />
      </form>

      <div class="mt-2 flex w-full p-2 space-x-2">
        <div class="w-1/3">
          <h3 class="text-center text-xs font-semibold opacity-80 uppercase">Autocomplete</h3>

          <ul class="mt-3 space-y-2">
            <%= for item <- @autocomplete do %>
              <li class="dark:bg-sky-700 bg-sky-100 rounded border dark:border-sky-500 border-sky-200 overflow-y-auto hover:bg-sky-200 hover:dark:bg-sky-600 transition">
                <a
                  href={"https://hexdocs.pm/#{item.package}/#{item.ref}"}
                  class="p-2 block w-full h-full"
                >
                  <div class="text-sm flex justify-between">
                    <span class="rounded dark:px-1.5 py-0.5 dark:bg-sky-800">
                      <%= item.package %> (<%= item.recent_downloads %>)
                    </span>
                    <span class="font-mono">BM25 = <%= abs(Float.round(item.rank, 2)) %></span>
                  </div>

                  <div class="mt-2">
                    <span class="text-sm font-mono font-semibold"><%= raw(item.title) %></span>
                  </div>
                </a>
              </li>
            <% end %>
          </ul>
        </div>

        <div class="w-1/3">
          <h3 class="text-center text-xs font-semibold opacity-80 uppercase">
            Full-text (press enter)
          </h3>

          <ul class="mt-3 space-y-2">
            <%= for item <- @fts do %>
              <li class="bg-teal-100 dark:bg-teal-700 rounded border border-teal-200 dark:border-teal-500 overflow-y-auto hover:bg-teal-300 dark:hover:bg-teal-600 transition">
                <a href={"https://hexdocs.pm/#{item.package}/#{item.ref}"} class="p-2 block">
                  <div class="text-sm flex justify-between">
                    <span class="rounded dark:px-1.5 py-0.5 dark:bg-teal-800">
                      <%= item.package %> (<%= item.recent_downloads %>)
                    </span>
                    <span class="font-mono">BM25 = <%= abs(Float.round(item.rank, 2)) %></span>
                  </div>

                  <div class="mt-2">
                    <span class="text-sm font-mono font-semibold"><%= raw(item.title) %></span>
                    <p class="mt-1 text-xs"><%= raw(item.doc) %></p>
                  </div>
                </a>
              </li>
            <% end %>
          </ul>
        </div>

        <div class="w-1/3">
          <h3 class="text-center text-xs font-semibold opacity-80 uppercase">
            Semantic (press enter)
          </h3>

          <ul class="mt-3 space-y-2">
            <%= for item <- @semantic do %>
              <li class="bg-indigo-100 dark:bg-indigo-700 rounded border border-indigo-200 dark:border-indigo-500 hover:bg-indigo-300 dark:hover:bg-indigo-600 transition">
                <a href={"https://hexdocs.pm/#{item.package}/#{item.ref}"} class="p-2 block">
                  <div class="text-sm flex justify-between">
                    <span class="rounded dark:px-1.5 py-0.5 dark:bg-indigo-800">
                      <%= item.package %>
                    </span>
                    <span class="font-mono">
                      Cosine similarity = <%= Float.round(item.similarity, 2) %>
                    </span>
                  </div>

                  <div class="mt-2">
                    <span class="text-sm font-mono font-semibold"><%= item.title %></span>
                    <p class="mt-1 text-xs"><%= item.doc %></p>
                  </div>
                </a>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  # TODO
  # package relations, ranking
  # read sqlite fts5 docs
  # read lunr.js docs, and ex_doc usage
  # improve autocomplete search (make it similar to ex_doc)
  # improve full-text search (make it similar to ex_doc)
  # faiss ivf vs hnswlib
  # sqlite vs typesense

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, autocomplete: [], fts: [], semantic: [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = params["query"]
    socket = assign(socket, query: query)

    socket =
      cond do
        query && String.trim(query) == "" ->
          assign(socket, autocomplete: [], fts: [], semantic: [])

        query ->
          %{query: query, packages: packages, anchor: anchor} = Wat.parse_query(query)

          assign(socket,
            autocomplete: Wat.autocomplete(query, packages, anchor),
            fts: Wat.fts(query, packages, anchor),
            semantic: Wat.list_similar_content(query, packages, anchor)
          )

        true ->
          assign(socket, autocomplete: [], fts: [], semantic: [])
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("autocomplete", %{"query" => query}, socket) do
    %{query: query, packages: packages, anchor: anchor} = Wat.parse_query(query)

    socket =
      assign(socket,
        autocomplete: Wat.autocomplete(query, packages, anchor),
        fts: [],
        semantic: []
      )

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/?#{%{query: query}}")}
  end
end
