defmodule GameServer.PoetryGameTest do
  use ExUnit.Case, async: true

  @name __MODULE__

  alias GameServer.PoetryGame

  setup do
    PoetryGame.start_link(name: @name)
    :ok
  end

  test "initial value" do
    assert PoetryGame.get(@name) == %{chatMessages: [], users: []}
  end

  test "add a user" do
    assert :ok == PoetryGame.add_user("Greg", @name)
    assert PoetryGame.get(@name).users == [
      %{ name: "Greg", papers: [] }
    ]
  end

  test "start game" do
    assert {:error, :too_few_players} == PoetryGame.start_game(@name)
    assert :ok == PoetryGame.add_user("A", @name)
    assert :ok == PoetryGame.add_user("B", @name)
    assert :ok == PoetryGame.add_user("C", @name)
    assert :ok == PoetryGame.start_game(@name)
    first_user = PoetryGame.get(@name).users |> Enum.at(0)
    assert first_user.papers |> length == 1
  end

  test "name too short" do
    assert {:error, :name_too_short} == PoetryGame.add_user("", @name)
  end

  test "name taken" do
    assert :ok == PoetryGame.add_user("Greg", @name)
    assert {:error, :name_taken} == PoetryGame.add_user("Greg", @name)
  end

  test "remove a user" do
    assert :ok == PoetryGame.add_user("Greg", @name)
    assert :ok == PoetryGame.remove_user("Greg", @name)
    assert PoetryGame.get(@name).users == []
  end

  test "set word" do
    PoetryGame.add_user("A", @name)
    PoetryGame.add_user("B", @name)
    PoetryGame.add_user("C", @name)
    assert :ok == PoetryGame.start_game(@name)
    assert :ok == PoetryGame.set_word("A", "Pea", @name)
    assert PoetryGame.get(@name) == %{
      chatMessages: [],
      users: [
        %{name: "A", papers: []},
        %{name: "B",
          papers: [
            %{poem: nil, poemAuthor: nil, question: nil,
              questionAuthor: nil, word: nil, wordAuthor: "B"},
            %{poem: nil, poemAuthor: nil, question: nil,
              questionAuthor: nil, word: "Pea", wordAuthor: "A"}]},
        %{name: "C",
          papers: [
            %{poem: nil, poemAuthor: nil, question: nil,
              questionAuthor: nil, word: nil, wordAuthor: "C"}]}]}
  end
end
