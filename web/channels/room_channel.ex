defmodule GameServer.RoomChannel do
  use GameServer.Web, :channel

  alias GameServer.PoetryGame

  defp user_name do
    Inspect.inspect(self(), [])
    |> String.slice(7..-4)
    # |> Integer.parse
    # i = rem(n, 26)
    # Enum.span("A","Z")
    # |> Enum.to_list
  end

  # defp with_user_index(state) do
  #   index = state.users
  #   |> Enum.find_index(fn u -> u.name == user_name end)
  #   len = length(state.users)
  #   new_users = state.users
  #   |> Stream.cycle
  #   |> Enum.slice(index, len)
  #   %{ state | users: new_users }
  #   |> Map.put(:current_user_index, 0)
  # end

  def join("room:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, state} = PoetryGame.add_user(user_name)
      send(self, :after_join)
      if length(state.users) >= 3 do
        send(self, :start_game)
      end
      {:ok, %{name: user_name}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    push socket, "name", %{name: user_name}
    state = PoetryGame.get
    broadcast socket, "state", state
    {:noreply, socket}
  end

  def handle_info(:start_game, socket) do
    {:ok, state} = PoetryGame.start_game
    broadcast socket, "state", state
    {:noreply, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("set_word", payload, socket) do
    IO.inspect "SET W"
    %{
      "word" => word
    } = payload
    {:ok, state} = PoetryGame.set_word(user_name, word)
    broadcast socket, "state", state
    {:reply, :ok, socket}
  end

  def handle_in("set_question", payload, socket) do
    IO.inspect "SET Q"
    %{
      "question" => question
    } = payload
    {:ok, state} = PoetryGame.set_question(user_name, question)
    broadcast socket, "state", state
    {:reply, :ok, socket}
  end

  def handle_in("set_poem", payload, socket) do
    IO.inspect "SET P"
    %{
      "poem" => poem
    } = payload
    {:ok, state} = PoetryGame.set_poem(user_name, poem)
    broadcast socket, "state", state
    {:reply, :ok, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("paper", payload, socket) do
    IO.inspect payload
    %{
      "poem" => poem,
      "question" => question,
      "user" => user,
      "word" => word
    } = payload
    {:reply, {:ok, payload}, socket}
  end

  # def handle_in("ready", payload, socket) do
  #   {:ok, state} = PoetryGame.set_ready(user_name)
  #   {:reply, {:ok, state}, socket}
  # end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # intercept ["start"]

  # def handle_out("shout", payload, socket) do
  #   IO.inspect shout_out: payload, from: user_name
  #   push socket, "shout", %{message: message, from: user_name}
  #   {:noreply, socket}
  # end

  # def handle_out("start", payload, socket) do
  #   push socket, "start", payload
  #   {:noreply, socket}
  # end

  # def handle_in("shout", msg, socket) do
  #   broadcast! socket, "shout", %{user: msg["user"], body: msg["body"]}
  #   {:reply, {:ok, %{msg: msg["body"]}}, assign(socket, :user, msg["user"])}
  # end

  def terminate(reason, socket) do
    {:ok, state} = PoetryGame.remove_user(user_name)
    push socket, "state", state
    {:ok}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
