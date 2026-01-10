defmodule HealthWeb.MessagesComponent do
  use HealthWeb, :live_component

  alias Health.Chat

  @emojis [
    # Health & Energy
    {"❤️", "Health"},
    {"💪", "Strength"},
    {"⭐", "Energy"},
    {"✨", "Wellness"},
    {"🔥", "Motivation"},
    {"⚡", "Power"},
    # Food
    {"🍎", "Apple"},
    {"🥕", "Carrot"},
    {"🥦", "Veggies"},
    {"🥗", "Salad"},
    {"🥚", "Protein"},
    {"🐟", "Fish"},
    # Space & Cosmic
    {"🚀", "Rocket"},
    {"🌟", "Stars"},
    {"🌙", "Moon"},
    {"☀️", "Sun"},
    {"🌈", "Rainbow"},
    {"☄️", "Comet"},
    # Positive
    {"👍", "Great"},
    {"👏", "Congrats"},
    {"🏆", "Winner"},
    {"✅", "Done"},
    {"🎯", "Goal"},
    {"🏅", "Achievement"}
  ]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(message: "")
     |> assign(show_emojis: false)
     |> assign(emojis: @emojis)}
  end

  @impl true
  def update(assigns, socket) do
    messages = Chat.list_recent_messages(100)

    socket =
      socket
      |> assign(assigns)
      |> assign(messages: messages)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    role = socket.assigns.role
    sender_role = if role == :nutritionist, do: "nutritionist", else: "seeker"

    case Chat.create_message(%{content: message, sender_role: sender_role}) do
      {:ok, _message} ->
        messages = Chat.list_recent_messages(100)
        {:noreply, assign(socket, message: "", show_emojis: false, messages: messages)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_event("toggle_emojis", _params, socket) do
    {:noreply, assign(socket, show_emojis: !socket.assigns.show_emojis)}
  end

  @impl true
  def handle_event("insert_emoji", %{"emoji" => emoji}, socket) do
    new_message = socket.assigns.message <> emoji
    {:noreply, assign(socket, message: new_message)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-[calc(100vh-12rem)]">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-2xl font-bold text-white">Messages</h2>
        <div class="flex items-center gap-2 text-sm text-purple-300">
          <span class={"w-2 h-2 rounded-full #{if @role == :nutritionist, do: "bg-emerald-400", else: "bg-blue-400"}"}></span>
          <span>Chatting as {role_display(@role)}</span>
        </div>
      </div>

      <div class="cosmic-card flex-1 rounded-2xl flex flex-col overflow-hidden">
        <div
          id="messages-container"
          class="flex-1 overflow-y-auto p-4 space-y-4"
          phx-hook="ScrollBottom"
        >
          <div :if={@messages == []} class="flex flex-col items-center justify-center h-full text-purple-300">
            <.icon name="hero-chat-bubble-left-right" class="w-16 h-16 opacity-50 mb-4" />
            <p class="text-lg">No messages yet</p>
            <p class="text-sm">Start the conversation!</p>
          </div>

          <div
            :for={message <- @messages}
            class={"flex #{if is_own_message(message, @role), do: "justify-end", else: "justify-start"}"}
          >
            <div class={"max-w-[70%] #{message_bubble_class(message, @role)}"}>
              <div class="flex items-center gap-2 mb-1">
                <span class={"text-xs font-medium #{sender_color(message.sender_role)}"}>
                  {sender_display(message.sender_role)}
                </span>
                <span class="text-xs text-purple-400/60">
                  {format_datetime(message.inserted_at)}
                </span>
              </div>
              <p class="text-white whitespace-pre-wrap break-words">{message.content}</p>
            </div>
          </div>
        </div>

        <div class="border-t border-purple-500/20 p-4">
          <div :if={@show_emojis} class="mb-3 p-3 bg-purple-900/30 rounded-lg">
            <div class="grid grid-cols-6 sm:grid-cols-8 md:grid-cols-12 gap-2">
              <button
                :for={{emoji, label} <- @emojis}
                phx-click="insert_emoji"
                phx-target={@myself}
                phx-value-emoji={emoji}
                class="p-2 text-xl hover:bg-purple-500/20 rounded-lg transition-colors"
                title={label}
              >
                {emoji}
              </button>
            </div>
          </div>

          <form phx-submit="send_message" phx-target={@myself} class="flex gap-3">
            <div class="flex-1 flex gap-2">
              <button
                type="button"
                phx-click="toggle_emojis"
                phx-target={@myself}
                class={"p-3 rounded-lg transition-colors #{if @show_emojis, do: "bg-purple-500 text-white", else: "bg-purple-900/30 text-purple-300 hover:bg-purple-500/20"}"}
              >
                <.icon name="hero-face-smile" class="w-5 h-5" />
              </button>

              <input
                type="text"
                name="message"
                value={@message}
                phx-change="update_message"
                phx-target={@myself}
                placeholder="Type your message..."
                autocomplete="off"
                class="flex-1 px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
              />
            </div>

            <button
              type="submit"
              disabled={@message == ""}
              class="px-6 py-3 cosmic-button rounded-lg font-medium flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <.icon name="hero-paper-airplane" class="w-5 h-5" />
              Send
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp is_own_message(message, role) do
    (message.sender_role == "nutritionist" && role == :nutritionist) ||
      (message.sender_role == "seeker" && role == :seeker)
  end

  defp message_bubble_class(message, role) do
    if is_own_message(message, role) do
      "p-3 rounded-2xl rounded-br-sm bg-purple-600/40"
    else
      "p-3 rounded-2xl rounded-bl-sm bg-purple-900/40"
    end
  end

  defp sender_color("nutritionist"), do: "text-emerald-400"
  defp sender_color("seeker"), do: "text-blue-400"

  defp sender_display("nutritionist"), do: "Nutritionist"
  defp sender_display("seeker"), do: "Health Seeker"

  defp role_display(:nutritionist), do: "Nutritionist"
  defp role_display(:seeker), do: "Health Seeker"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end
end
