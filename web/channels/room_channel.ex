defmodule GameServer.RoomChannel do
  use GameServer.Web, :channel

  alias GameServer.PoetryGame
  alias GameServer.Room

  @name :poetry_game

  defp user_name do
    Inspect.inspect(self(), [])
    |> String.slice(7..-4)
    # |> Integer.parse
    # i = rem(n, 26)
    # Enum.span("A","Z")
    # |> Enum.to_list
  end

  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, state} = Room.add_room_member(@name, user_name())
      send(self(), :after_join)
      if map_size(state.room.members) >= 3 && length(state.game.players) == 0 do
        send(self(), :start_game)
      end
      {:ok, %{name: user_name()}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    push socket, "name", %{name: user_name()}
    state = Room.state(@name)
    broadcast socket, "shout", %{from: "Server", message: "User #{user_name()} joined"}
    broadcast socket, "state", state
    {:noreply, socket}
  end

  def handle_info(:start_game, socket) do
    {:ok, state} = PoetryGame.start_game(@name)
    broadcast socket, "state", state
    {:noreply, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("set_word", payload, socket) do
    # IO.inspect "SET W"
    %{
      "word" => word
    } = payload
    {:ok, state} = PoetryGame.set_word(@name, user_name(), word)
    broadcast socket, "state", state
    {:reply, :ok, socket}
  end

  def handle_in("set_question", payload, socket) do
    # IO.inspect "SET Q"
    %{
      "question" => question
    } = payload
    {:ok, state} = PoetryGame.set_question(@name, user_name(), question)
    broadcast socket, "state", state
    {:reply, :ok, socket}
  end

  def handle_in("set_poem", payload, socket) do
    # IO.inspect "SET P"
    %{
      "poem" => poem
    } = payload
    {:ok, state} = PoetryGame.set_poem(@name, user_name(), poem)
    broadcast socket, "state", state
    {:reply, :ok, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("paper", payload, socket) do
    # IO.inspect payload
    %{
      "poem" => _poem,
      "question" => _question,
      "user" => _user,
      "word" => _word
    } = payload
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # TODO: more robust handling of people leaving
  #
  # https://stackoverflow.com/questions/33934029/how-to-detect-if-a-user-left-a-phoenix-channel-due-to-a-network-disconnect
  def terminate({_, reason}, socket) do
    {:ok, _} = Room.remove_room_member(@name, user_name())
    broadcast socket, "shout", %{from: "Server", message: "User #{user_name()} left (#{reason})"}
    {:ok, state} = PoetryGame.remove_player(@name, user_name())
    broadcast socket, "state", state
    {:ok}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
