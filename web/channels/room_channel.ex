defmodule GameServer.RoomChannel do
  use GameServer.Web, :channel

  alias GameServer.PoetryGame

  defp user_name do
    Inspect.inspect(self(), [])
    |> String.slice(5..-2)
  end

  defp with_user_index(state) do
    index = state.users
    |> Enum.find_index(fn u -> u.name == user_name end)
    len = length(state.users)
    new_users = state.users
    |> Stream.cycle
    |> Enum.slice(index, len)
    %{ state | users: new_users }
    |> Map.put(:current_user_index, 0)
  end

  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, state} = PoetryGame.add_user(user_name)
      if length(state.users) >= 3 do
        {:ok, state} = PoetryGame.start_game
        broadcast socket, "start", state
      end
      {:ok, state, socket}
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
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  def handle_in("ready", payload, socket) do
    {:ok, state} = PoetryGame.set_ready(user_name)
    {:reply, {:ok, state}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  def handle_out("start", payload, socket) do
    push socket, "new_msg", payload |> with_user_index
    {:noreply, socket}
  end

  # def handle_in("shout", msg, socket) do
  #   broadcast! socket, "shout", %{user: msg["user"], body: msg["body"]}
  #   {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  # end

  def terminate(reason, socket) do
    PoetryGame.remove_user(user_name)
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
