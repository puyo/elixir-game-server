defmodule GameServer.PageController do
  use GameServer.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
