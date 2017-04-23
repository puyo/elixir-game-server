defmodule GameServer.PoetryGame do
  @name :poetry_game

  @initial_state %{
    users: [],
    chat_messages: []
  }

  @initial_paper %{
    word: nil,
    question: nil,
    poem: nil,
    word_author: nil,
    question_author: nil,
    poem_author: nil,
  }

  @min_players 3

  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, @name)
    Agent.start_link(fn -> @initial_state end, opts)
  end

  def get(name \\ @name) do
    Agent.get name, fn state -> state end
  end

  def start_game(name \\ @name) do
    Agent.get_and_update name, fn state ->
      if length(state.users) < @min_players do
        {{:error, :too_few_players}, state}
      else
        new_users = state.users
        |> Enum.map(fn user -> user_with_new_paper(user) end)
        state = %{ state | users: new_users }
        {{:ok, state}, state}
      end
    end
  end

  def add_user(user_name, name \\ @name)
  def add_user("", _), do: {:error, :name_too_short}
  def add_user(user_name, name) do
    Agent.get_and_update name, fn state ->
      if state.users |> Enum.find(with_user_name(user_name)) do
        {{:error, :name_taken}, state}
      else
        new_user = %{
          name: user_name,
          papers: [],
          ready: false,
        }
        new_users = state.users |> List.insert_at(-1, new_user)
        new_state = %{ state | users: new_users }
        {{:ok, new_state}, new_state}
      end
    end
  end

  def remove_user(user_name, name \\ @name) do
    Agent.get_and_update name, fn state ->
      new_users = state.users
      |> Enum.reject(with_user_name(user_name))
      new_state = %{ state | users: new_users }
      {{:ok, new_state}, new_state}
    end
  end

  defp user_with_new_paper(user) do
    %{ user | papers: [ %{ @initial_paper | word_author: user.name } ]}
  end

  defp with_user_name(user_name) do
    fn u -> user_name == u.name end
  end

  def set_ready(user_name, value, name \\ @name) do
    Agent.get_and_update name, fn state ->
      new_users = state.users
      |> Enum.reject(with_user_name(user_name))
      new_state = %{ state | users: new_users }
      {{:ok, new_state}, new_state}
    end
  end

  defp update_user(users, user_name, fun) do
    index = users |> Enum.find_index(with_user_name(user_name))
    users |> List.update_at(index, fun)
  end

  def set_word(user_name, word, name \\ @name) do
    set_value(user_name, :word, :word_author, word, false, name)
  end

  def set_question(user_name, question, name \\ @name) do
    set_value(user_name, :question, :question_author, question, false, name)
  end

  def set_poem(user_name, poem, name \\ @name) do
    set_value(user_name, :poem, :poem_author, poem, true, name)
  end

  defp update_paper_in_place(users, user_index, new_paper) do
    users
    |> Enum.with_index
    |> Enum.map(fn ({user, index}) ->
      cond do
        index == user_index ->
          new_papers = user.papers
          |> List.replace_at(0, new_paper)

          %{ user | papers: new_papers }

        true ->
          user
      end
    end)
  end

  defp update_paper_and_move(users, user_index, new_paper) do
    insert_index = rem(user_index + 1, length(users))

    users
    |> Enum.with_index
    |> Enum.map(fn ({user, index}) ->
      cond do
        index == user_index ->
          [_old_paper | new_papers] = user.papers

          %{ user | papers: new_papers }

        index == insert_index ->
          new_papers = user.papers
          |> List.insert_at(-1, new_paper)

          %{ user | papers: new_papers }

        true ->
          user
      end
    end)
  end

  defp set_value(user_name, key, author_key, value, is_last_key, name) do
    Agent.get_and_update name, fn state ->
      old_index = state.users
      |> Enum.find_index(with_user_name(user_name))

      old_user = state.users
      |> Enum.at(old_index)

      [old_paper|_rest] = old_user.papers

      new_paper = %{
        old_paper |
        key => value,
        author_key => user_name
      }

      new_users = if is_last_key do
        update_paper_in_place(state.users, old_index, new_paper)
      else
        update_paper_and_move(state.users, old_index, new_paper)
      end

      new_state = %{ state | users: new_users }
      {{:ok, new_state}, new_state}
    end
  end
end
