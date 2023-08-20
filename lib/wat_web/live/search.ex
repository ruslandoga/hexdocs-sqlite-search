defmodule WatWeb.SearchLive do
  use WatWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen max-w-2xl mx-auto">
      <form id="ask-form" class="w-full" phx-submit="ask">
        <input
          type="text"
          name="question"
          placeholder="Ask a question about Elixir ecosystem..."
          class="mt-4 w-full dark:bg-zinc-500 dark:border-zinc-400"
        />
      </form>

      <%= if @answer do %>
        <div class="mt-4 prose prose-zinc dark:prose-invert"><%= raw(@answer) %></div>
        <div class="mt-4 text-xs font-mono">It took <%= @duration %> ms to answer</div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, answering: false), temporary_assigns: [answer: nil, duration: nil]}
  end

  # TODO debounce
  @impl true
  def handle_event("ask", %{"question" => question}, %{assigns: %{answering: false}} = socket) do
    lv = self()

    Task.start(fn ->
      start_at = System.monotonic_time(:millisecond)
      answer = answer(question)
      end_at = System.monotonic_time(:millisecond)
      send(lv, {:answer, answer, _duration = end_at - start_at})
    end)

    {:noreply, assign(socket, answering: true)}
  end

  @impl true
  def handle_info({:answer, answer, duration}, socket) when is_binary(answer) do
    socket =
      case Earmark.as_html(answer) do
        {:ok, html, _} -> assign(socket, answer: html, duration: duration)
        _ -> assign(socket, answer: answer, duration: duration)
      end

    {:noreply, assign(socket, answering: false)}
  end

  defp answer(question) do
    # search docs_fts title, doc
    # search docs embedding
    # search similar packages
    """
    nothing found for question:

    #{question}
    """
  end
end
