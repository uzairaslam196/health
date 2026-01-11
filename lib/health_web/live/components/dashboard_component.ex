defmodule HealthWeb.DashboardComponent do
  use HealthWeb, :live_component

  alias Health.Nutrition
  alias Health.Nutrition.Rhythm
  alias Health.Chat

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    orbits = Nutrition.list_orbits()
    today_rhythms = Nutrition.list_rhythms_by_date(Date.utc_today())
    recent_messages = Chat.list_recent_messages(5)

    stats = calculate_today_stats(today_rhythms)

    socket =
      socket
      |> assign(assigns)
      |> assign(orbits: orbits)
      |> assign(today_rhythms: today_rhythms)
      |> assign(recent_messages: recent_messages)
      |> assign(stats: stats)

    {:ok, socket}
  end

  defp calculate_today_stats(rhythms) do
    total = length(rhythms)
    completed = Enum.count(rhythms, &(&1.status == "completed"))
    skipped = Enum.count(rhythms, &(&1.status == "skipped"))
    pending = Enum.count(rhythms, &(&1.status == "pending"))

    %{
      total: total,
      completed: completed,
      skipped: skipped,
      pending: pending,
      completion_rate: if(total > 0, do: round(completed / total * 100), else: 0)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6 sm:space-y-8">
      <div class="text-center mb-4 sm:mb-8">
        <h1 class="text-2xl sm:text-3xl font-bold text-white mb-2">
          Welcome, {role_greeting(@role)}
        </h1>
        <p class="text-purple-200 text-sm sm:text-base">
          {Date.utc_today() |> Calendar.strftime("%A, %B %d, %Y")}
        </p>
      </div>

      <div class="grid grid-cols-2 md:grid-cols-4 gap-2 sm:gap-4">
        <.stat_card label="Today's Rhythms" value={@stats.total} icon="hero-sparkles" color="purple" />
        <.stat_card label="Completed" value={@stats.completed} icon="hero-check-circle" color="green" />
        <.stat_card label="Skipped" value={@stats.skipped} icon="hero-x-circle" color="red" />
        <.stat_card label="Pending" value={@stats.pending} icon="hero-clock" color="yellow" />
      </div>

      <div class="grid md:grid-cols-2 gap-4 sm:gap-6">
        <div class="cosmic-card p-4 sm:p-6 rounded-2xl">
          <h3 class="text-base sm:text-lg font-semibold text-white mb-3 sm:mb-4 flex items-center gap-2">
            <.icon name="hero-calendar-days" class="w-5 h-5 text-purple-400" />
            Today's Schedule
          </h3>

          <div :if={@today_rhythms == []} class="text-purple-300 text-center py-6 sm:py-8">
            <.icon name="hero-calendar" class="w-10 h-10 sm:w-12 sm:h-12 mx-auto mb-2 opacity-50" />
            <p class="text-sm sm:text-base">No rhythms scheduled for today</p>
          </div>

          <div :if={@today_rhythms != []} class="space-y-2 sm:space-y-3">
            <div
              :for={rhythm <- Enum.sort_by(@today_rhythms, &Rhythm.rhythm_order(&1.meal_type))}
              class={"flex items-center justify-between p-2 sm:p-3 rounded-lg #{rhythm_status_bg(rhythm.status)}"}
            >
              <div class="flex items-center gap-2 sm:gap-3 min-w-0 flex-1">
                <span class={"px-2 py-0.5 sm:py-1 rounded text-xs font-medium shrink-0 #{type_badge_class(rhythm.meal_type)}"}>
                  {Rhythm.rhythm_display(rhythm.meal_type)}
                </span>
                <p class="text-white font-medium text-sm sm:text-base truncate">{rhythm.name}</p>
              </div>
              <span class={"px-2 py-0.5 sm:py-1 rounded text-xs font-medium shrink-0 ml-2 #{rhythm_status_badge(rhythm.status)}"}>
                {rhythm.status |> String.capitalize()}
              </span>
            </div>
          </div>
        </div>

        <div class="cosmic-card p-6 rounded-2xl">
          <h3 class="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <.icon name="hero-chat-bubble-left-right" class="w-5 h-5 text-purple-400" />
            Recent Messages
          </h3>

          <div :if={@recent_messages == []} class="text-purple-300 text-center py-8">
            <.icon name="hero-chat-bubble-left" class="w-12 h-12 mx-auto mb-2 opacity-50" />
            <p>No messages yet</p>
          </div>

          <div :if={@recent_messages != []} class="space-y-3">
            <div
              :for={message <- @recent_messages}
              class="p-3 rounded-lg bg-purple-900/20"
            >
              <div class="flex items-center gap-2 mb-1">
                <span class={"text-xs font-medium #{sender_color(message.sender_role)}"}>
                  {sender_display(message.sender_role)}
                </span>
                <span class="text-purple-400 text-xs">
                  {format_time(message.inserted_at)}
                </span>
              </div>
              <p class="text-purple-200 text-sm line-clamp-2">{message.content}</p>
            </div>
          </div>
        </div>
      </div>

      <div class="cosmic-card p-6 rounded-2xl">
        <h3 class="text-lg font-semibold text-white mb-4 flex items-center gap-2">
          <.icon name="hero-sparkles" class="w-5 h-5 text-purple-400" />
          Active Orbits
        </h3>

        <div :if={@orbits == []} class="text-purple-300 text-center py-8">
          <.icon name="hero-sparkles" class="w-12 h-12 mx-auto mb-2 opacity-50" />
          <p>No orbits created yet</p>
          <.link
            navigate={~p"/space?tab=plans"}
            class="inline-block mt-4 text-purple-400 hover:text-purple-300"
          >
            Create your first orbit
          </.link>
        </div>

        <div :if={@orbits != []} class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.link
            :for={orbit <- Enum.take(@orbits, 3)}
            patch={~p"/space?tab=plans"}
            class="p-4 rounded-lg bg-purple-900/20 border border-purple-500/20 hover:border-purple-400 hover:bg-purple-900/30 transition-all cursor-pointer block"
          >
            <h4 class="text-white font-medium mb-2">{orbit.name}</h4>
            <p class="text-purple-300 text-sm mb-3 line-clamp-2">{orbit.description || "No description"}</p>
            <div class="flex items-center gap-2 text-xs text-purple-400">
              <.icon name="hero-calendar" class="w-4 h-4" />
              <span>{format_date(orbit.start_date)}</span>
              <span :if={orbit.end_date}>- {format_date(orbit.end_date)}</span>
            </div>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp stat_card(assigns) do
    color_classes = %{
      "purple" => "from-purple-500/20 to-purple-600/20 border-purple-500/30",
      "green" => "from-emerald-500/20 to-emerald-600/20 border-emerald-500/30",
      "red" => "from-red-500/20 to-red-600/20 border-red-500/30",
      "yellow" => "from-yellow-500/20 to-yellow-600/20 border-yellow-500/30"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, ""))

    ~H"""
    <div class={"cosmic-card p-3 sm:p-4 rounded-xl bg-gradient-to-br #{@color_class} border"}>
      <div class="flex items-center gap-2 sm:gap-3">
        <.icon name={@icon} class="w-6 h-6 sm:w-8 sm:h-8 text-purple-300 shrink-0" />
        <div class="min-w-0">
          <p class="text-xl sm:text-2xl font-bold text-white">{@value}</p>
          <p class="text-purple-300 text-xs truncate">{@label}</p>
        </div>
      </div>
    </div>
    """
  end

  defp role_greeting(:nutritionist), do: "Nutritionist"
  defp role_greeting(:seeker), do: "Health Seeker"

  defp type_badge_class("dawn"), do: "bg-pink-500/30 text-pink-300"
  defp type_badge_class("morning"), do: "bg-amber-500/30 text-amber-300"
  defp type_badge_class("midday"), do: "bg-yellow-500/30 text-yellow-300"
  defp type_badge_class("afternoon"), do: "bg-orange-500/30 text-orange-300"
  defp type_badge_class("evening"), do: "bg-rose-500/30 text-rose-300"
  defp type_badge_class("night"), do: "bg-indigo-500/30 text-indigo-300"
  defp type_badge_class("late_night"), do: "bg-purple-500/30 text-purple-300"
  defp type_badge_class(_), do: "bg-purple-500/30 text-purple-300"

  defp rhythm_status_bg("completed"), do: "bg-emerald-900/20"
  defp rhythm_status_bg("skipped"), do: "bg-red-900/20"
  defp rhythm_status_bg(_), do: "bg-purple-900/20"

  defp rhythm_status_badge("completed"), do: "bg-emerald-500/20 text-emerald-300"
  defp rhythm_status_badge("skipped"), do: "bg-red-500/20 text-red-300"
  defp rhythm_status_badge(_), do: "bg-purple-500/20 text-purple-300"

  defp sender_color("nutritionist"), do: "text-emerald-400"
  defp sender_color("seeker"), do: "text-blue-400"

  defp sender_display("nutritionist"), do: "Nutritionist"
  defp sender_display("seeker"), do: "Health Seeker"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M")
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %d")
  end
end
