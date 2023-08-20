defmodule WatWeb.DocsController do
  use WatWeb, :controller
  import Ecto.Query

  def show(conn, %{"package" => package}) do
    docs =
      "docs"
      |> where(package: ^package)
      |> select([d], map(d, [:id, :ref, :title, :doc, :type]))
      |> order_by([d], asc: d.id)
      |> Wat.Repo.all()

    render(conn, "show.html", package: package, docs: docs)
  end
end
