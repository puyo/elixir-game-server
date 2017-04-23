defmodule GameServer.RoomChannel do
  use GameServer.Web, :channel

  alias GameServer.PoetryGame

  def user_name do
    Inspect.inspect(self(), []) |> String.slice(5..-2)
  end

  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      { :ok, state } = PoetryGame.add_user(user_name)

      { :ok, state, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("paper", payload, socket) do
    %{
      "poem" => poem,
      "question" => question,
      "user" => user,
      "word" => word
    } = payload
    #IO.inspect poem, user, word
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  def handle_in("shout", payload, socket) do
    #IO.inspect fn: :shout, payload: payload
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # def handle_in("shout", msg, socket) do
  #   broadcast! socket, "shout", %{user: msg["user"], body: msg["body"]}
  #   {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  # end

  def terminate(reason, socket) do
    #IO.inspect fn: :terminate, reason: reason
    PoetryGame.remove_user(user_name)
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
