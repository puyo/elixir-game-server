defmodule GameServer.PoetryGameTest do
  use ExUnit.Case, async: true

  @name __MODULE__

  alias GameServer.PoetryGame

  setup do
    PoetryGame.start_link(name: @name)
    :ok
  end

  test "initial value" do
    state = PoetryGame.get(@name)
    assert state == %{chat_messages: [], users: []}
  end

  test "add a user" do
    { :ok, state } = PoetryGame.add_user("Greg", @name)
    assert state.users == [
      %{ name: "Greg", papers: [] }
    ]
  end

  test "start game" do
    { :error, :too_few_players } = PoetryGame.start_game(@name)
    { :ok, _ } = PoetryGame.add_user("A", @name)
    { :ok, _ } = PoetryGame.add_user("B", @name)
    { :ok, _ } = PoetryGame.add_user("C", @name)
    { :ok, state } = PoetryGame.start_game(@name)
    first_user = state.users |> Enum.at(0)
    assert first_user.papers |> length == 1
  end

  test "name too short" do
    { status, reason } = PoetryGame.add_user("", @name)
    assert status == :error
    assert reason == :name_too_short
  end

  test "name taken" do
    assert { :ok, _ } = PoetryGame.add_user("Greg", @name)
    assert { :error, :name_taken } = PoetryGame.add_user("Greg", @name)
  end

  test "remove a user" do
    assert { :ok, _ } = PoetryGame.add_user("Greg", @name)
    assert { :ok, state } = PoetryGame.remove_user("Greg", @name)
    assert state.users == []
  end

  test "set word" do
    { :ok, _ } = PoetryGame.add_user("A", @name)
    { :ok, _ } = PoetryGame.add_user("B", @name)
    { :ok, _ } = PoetryGame.add_user("C", @name)
    { :ok, _ } = PoetryGame.start_game(@name)
    { :ok, state } = PoetryGame.set_word("A", "Pea", @name)
    assert state == %{
      chat_messages: [],
      users: [
        %{name: "A", papers: []},
        %{name: "B",
          papers: [
            %{poem: nil, poem_author: nil, question: nil,
              question_author: nil, word: nil, word_author: "B"},
            %{poem: nil, poem_author: nil, question: nil,
              question_author: nil, word: "Pea", word_author: "A"}]},
        %{name: "C",
          papers: [
            %{poem: nil, poem_author: nil, question: nil,
              question_author: nil, word: nil, word_author: "C"}]}]}
  end
end
