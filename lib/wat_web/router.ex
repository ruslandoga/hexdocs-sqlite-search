defmodule WatWeb.Router do
  use WatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {WatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", WatWeb do
    pipe_through :browser

    live "/", SearchLive, :index
    get "/docs/:package", DocsController, :show
    get "/v0/search", SearchController, :search
  end

  # Other scopes may use custom stacks.
  # scope "/api", WatWeb do
  #   pipe_through :api
  # end
end
