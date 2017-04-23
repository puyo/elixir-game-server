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
    {:ok, state} = PoetryGame.add_user("Greg", @name)
    assert state.users == [
      %{name: "Greg", papers: [], state: :not_playing}
    ]
  end

  test "start game" do
    {:error, :too_few_players} = PoetryGame.start_game(@name)
    {:ok, _} = PoetryGame.add_user("A", @name)
    {:ok, _} = PoetryGame.add_user("B", @name)
    {:ok, _} = PoetryGame.add_user("C", @name)
    {:ok, state} = PoetryGame.start_game(@name)
    first_user = state.users |> Enum.at(0)
    assert first_user.papers |> length == 1
  end

  test "name too short" do
    {status, reason} = PoetryGame.add_user("", @name)
    assert status == :error
    assert reason == :name_too_short
  end

  test "name taken" do
    assert {:ok, _} = PoetryGame.add_user("Greg", @name)
    assert {:error, :name_taken} = PoetryGame.add_user("Greg", @name)
  end

  test "remove a user" do
    assert {:ok, _} = PoetryGame.add_user("Greg", @name)
    assert {:ok, state} = PoetryGame.remove_user("Greg", @name)
    assert state.users == []
  end

  test "set word" do
    {:ok, _} = PoetryGame.add_user("A", @name)
    {:ok, _} = PoetryGame.add_user("B", @name)
    {:ok, _} = PoetryGame.add_user("C", @name)
    {:ok, _} = PoetryGame.start_game(@name)
    {:ok, state} = PoetryGame.set_word("A", "Pea", @name)
    assert state == %{
      chat_messages: [],
      users: [
        %{name: "A", papers: [], state: :playing},
        %{name: "B",
          papers: [
            %{poem: nil, question: nil, word: nil},
            %{poem: nil, question: nil, word: "Pea"}
          ],
          state: :playing
        },
        %{name: "C",
          papers: [
            %{poem: nil, question: nil, word: nil}
          ],
          state: :playing
        }
      ]
    }
  end

  test "set question" do
    {:ok, _} = PoetryGame.add_user("A", @name)
    {:ok, _} = PoetryGame.add_user("B", @name)
    {:ok, _} = PoetryGame.add_user("C", @name)
    {:ok, _} = PoetryGame.start_game(@name)
    {:ok, state} = PoetryGame.set_word("A", "WA", @name)
    assert state == %{
      chat_messages: [],
      users: [
        %{name: "A", papers: [], state: :playing},
        %{name: "B",
          papers: [
            %{poem: nil, question: nil, word: nil},
            %{poem: nil, question: nil, word: "WA"}
          ],
          state: :playing
        },
        %{name: "C",
          papers: [
            %{poem: nil, question: nil, word: nil}
          ],
          state: :playing
        }
      ]
    }
    {:ok, _} = PoetryGame.set_word("B", "WB", @name)
    {:ok, state} = PoetryGame.set_question("B", "QB", @name)
    assert state == %{
      chat_messages: [],
      users: [
        %{name: "A", papers: [], state: :playing},
        %{name: "B", papers: [], state: :playing},
        %{name: "C",
          papers: [
            %{poem: nil, question: nil, word: nil},
            %{poem: nil, question: nil, word: "WB"},
            %{poem: nil, question: "QB", word: "WA"}
          ],
          state: :playing
        }
      ]
    }
  end
end
