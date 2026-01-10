defmodule Health.ChatTest do
  use Health.DataCase, async: true

  alias Health.Chat
  alias Health.Chat.Message

  describe "messages" do
    @valid_attrs %{content: "Hello, how are you feeling today?", sender_role: "nutritionist"}
    @seeker_attrs %{content: "I'm feeling great!", sender_role: "seeker"}
    @invalid_attrs %{content: nil, sender_role: nil}

    def message_fixture(attrs \\ %{}) do
      {:ok, message} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Chat.create_message()

      message
    end

    test "list_messages/0 returns all messages in order" do
      message1 = message_fixture()
      message2 = message_fixture(@seeker_attrs)

      messages = Chat.list_messages()
      assert length(messages) == 2
      assert hd(messages).id == message1.id
      assert List.last(messages).id == message2.id
    end

    test "list_recent_messages/1 returns limited messages" do
      for i <- 1..5 do
        message_fixture(%{content: "Message #{i}"})
      end

      messages = Chat.list_recent_messages(3)
      assert length(messages) == 3
    end

    test "get_message!/1 returns the message with given id" do
      message = message_fixture()
      assert Chat.get_message!(message.id) == message
    end

    test "create_message/1 with valid nutritionist data creates a message" do
      assert {:ok, %Message{} = message} = Chat.create_message(@valid_attrs)
      assert message.content == "Hello, how are you feeling today?"
      assert message.sender_role == "nutritionist"
    end

    test "create_message/1 with valid seeker data creates a message" do
      assert {:ok, %Message{} = message} = Chat.create_message(@seeker_attrs)
      assert message.content == "I'm feeling great!"
      assert message.sender_role == "seeker"
    end

    test "create_message/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Chat.create_message(@invalid_attrs)
    end

    test "create_message/1 with invalid sender_role returns error" do
      attrs = %{content: "Test", sender_role: "invalid_role"}
      assert {:error, changeset} = Chat.create_message(attrs)
      assert "is invalid" in errors_on(changeset).sender_role
    end

    test "create_message/1 with empty content returns error" do
      attrs = %{content: "", sender_role: "nutritionist"}
      assert {:error, changeset} = Chat.create_message(attrs)
      assert "can't be blank" in errors_on(changeset).content
    end

    test "create_message/1 with content too long returns error" do
      long_content = String.duplicate("a", 5001)
      attrs = %{content: long_content, sender_role: "nutritionist"}
      assert {:error, changeset} = Chat.create_message(attrs)
      assert "should be at most 5000 character(s)" in errors_on(changeset).content
    end

    test "create_message/1 supports emoji content" do
      attrs = %{content: "Great job today! Keep it up!", sender_role: "nutritionist"}
      assert {:ok, %Message{} = message} = Chat.create_message(attrs)
      assert message.content == "Great job today! Keep it up!"
    end

    test "delete_message/1 deletes the message" do
      message = message_fixture()
      assert {:ok, %Message{}} = Chat.delete_message(message)
      assert_raise Ecto.NoResultsError, fn -> Chat.get_message!(message.id) end
    end

    test "change_message/1 returns a message changeset" do
      message = message_fixture()
      assert %Ecto.Changeset{} = Chat.change_message(message)
    end
  end

  describe "pubsub" do
    test "subscribe/0 subscribes to message updates" do
      assert :ok = Chat.subscribe()
    end

    test "create_message/1 broadcasts to subscribers" do
      Chat.subscribe()

      {:ok, message} = Chat.create_message(@valid_attrs)

      assert_receive {:message_created, ^message}
    end
  end
end
