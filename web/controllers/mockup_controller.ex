defmodule GameServer.MockupController do
  use GameServer.Web, :controller

  def paper_burst(conn, _params) do
    render conn, "paper_burst.html"
  end
end
