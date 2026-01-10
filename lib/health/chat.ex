defmodule Health.Chat do
  @moduledoc """
  The Chat context handles messaging between nutritionist and health seeker.
  """

  import Ecto.Query, warn: false
  alias Health.Repo
  alias Health.Chat.Message

  @topic "chat:messages"

  @doc """
  Returns the list of messages ordered by creation time.
  """
  def list_messages do
    Message
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the most recent messages, limited by count.
  """
  def list_recent_messages(limit \\ 100) do
    Message
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  @doc """
  Gets a single message.
  """
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Creates a message and broadcasts it.
  """
  def create_message(attrs \\ %{}) do
    result =
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        broadcast({:ok, message}, :message_created)
        {:ok, message}

      error ->
        error
    end
  end

  @doc """
  Deletes a message.
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking message changes.
  """
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  @doc """
  Subscribe to message updates.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(Health.PubSub, @topic)
  end

  defp broadcast({:ok, message}, event) do
    Phoenix.PubSub.broadcast(Health.PubSub, @topic, {event, message})
    {:ok, message}
  end

  defp broadcast({:error, _} = error, _event), do: error
end
