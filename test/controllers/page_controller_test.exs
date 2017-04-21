defmodule GameServer.PageControllerTest do
  use GameServer.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Elixir Game Server"
  end
end
