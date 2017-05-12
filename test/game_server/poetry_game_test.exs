defmodule GameServer.PoetryGameTest do
  use ExUnit.Case, async: true

  @name __MODULE__

  alias GameServer.PoetryGame
  alias GameServer.Room

  setup do
    PoetryGame.start_link(name: @name)
    :ok
  end

  test "start game" do
    {:error, :too_few_players} = PoetryGame.start_game(@name)
    {:ok, _} = Room.add_room_member(@name, "A")
    {:ok, _} = Room.add_room_member(@name, "B")
    {:ok, _} = Room.add_room_member(@name, "C")
    {:ok, state} = PoetryGame.start_game(@name)
    first_player = state.game.players |> Enum.at(0)
    assert first_player.papers |> length == 1
  end

  test "remove player" do
    {:ok, _} = Room.add_room_member(@name, "A")
    {:ok, _} = Room.add_room_member(@name, "B")
    {:ok, _} = Room.add_room_member(@name, "C")
    {:ok, _} = PoetryGame.start_game(@name)
    {:ok, state} = PoetryGame.remove_player(@name, "B")
    assert state.game.players == [] # reset to initial
  end

  test "name too short" do
    {status, reason} = Room.add_room_member(@name, "")
    assert status == :error
    assert reason == :name_too_short
  end

  test "name taken" do
    assert {:ok, _} = Room.add_room_member(@name, "Greg")
    assert {:error, :name_taken} = Room.add_room_member(@name, "Greg")
  end

  test "set word, question, poem" do
    {:ok, _} = Room.add_room_member(@name, "A")
    {:ok, _} = Room.add_room_member(@name, "B")
    {:ok, _} = Room.add_room_member(@name, "C")
    {:ok, _} = PoetryGame.start_game(@name)
    {:ok, state} = PoetryGame.set_word(@name, "A", "WA")
    assert state.game.players == [
      %{name: "A", papers: []},
      %{name: "B",
        papers: [
          %{poem: nil, question: nil, word: nil},
          %{poem: nil, question: nil, word: "WA"}
        ]
      },
      %{name: "C",
        papers: [
          %{poem: nil, question: nil, word: nil}
        ]
      }
    ]
    {:ok, _} = PoetryGame.set_word(@name, "B", "WB")
    {:ok, state} = PoetryGame.set_question(@name, "B", "QB")
    assert state.game.players == [
      %{name: "A", papers: []},
      %{name: "B", papers: []},
      %{name: "C",
        papers: [
          %{poem: nil, question: nil, word: nil},
          %{poem: nil, question: nil, word: "WB"},
          %{poem: nil, question: "QB", word: "WA"}
        ]
      }
    ]
    {:ok, _} = PoetryGame.set_word(@name, "C", "C")
    {:ok, _} = PoetryGame.set_question(@name, "C", "QC")
    {:ok, state} = PoetryGame.set_poem(@name, "C", "PC")
    assert state.game.players == [
      %{name: "A", papers: [
           %{poem: nil, question: nil, word: "C"},
           %{poem: nil, question: "QC", word: "WB"}
         ]},
      %{name: "B", papers: []},
      %{name: "C",
        papers: [
          %{poem: "PC", question: "QB", word: "WA"}
        ]
      }
    ]
  end
end
