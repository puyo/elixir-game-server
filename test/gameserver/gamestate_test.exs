defmodule GameServer.GameStateTest do
  use ExUnit.Case, async: true

  @name __MODULE__

  alias GameServer.GameState

  setup do
    GameState.start_link(name: @name)
    :ok
  end

  test "initial value" do
    assert GameState.get(@name) == %{chatMessages: [], users: []}
  end

  test "add a user" do
    assert :ok == GameState.add_user("Greg", @name)
    assert GameState.get(@name).users == [
      %{ name: "Greg", papers: [] }
    ]
  end

  test "start game" do
    assert {:error, :too_few_players} == GameState.start_game(@name)
    assert :ok == GameState.add_user("A", @name)
    assert :ok == GameState.add_user("B", @name)
    assert :ok == GameState.add_user("C", @name)
    assert :ok == GameState.start_game(@name)
    first_user = GameState.get(@name).users |> Enum.at(0)
    assert first_user.papers |> length == 1
  end

  test "name too short" do
    assert {:error, :name_too_short} == GameState.add_user("", @name)
  end

  test "name taken" do
    assert :ok == GameState.add_user("Greg", @name)
    assert {:error, :name_taken} == GameState.add_user("Greg", @name)
  end

  test "remove a user" do
    assert :ok == GameState.add_user("Greg", @name)
    assert :ok == GameState.remove_user("Greg", @name)
    assert GameState.get(@name).users == []
  end

  test "set word" do
    GameState.add_user("A", @name)
    GameState.add_user("B", @name)
    GameState.add_user("C", @name)
    assert :ok == GameState.start_game(@name)
    assert :ok == GameState.set_word("A", "Pea", @name)
    assert GameState.get(@name) == nil
  end

end
