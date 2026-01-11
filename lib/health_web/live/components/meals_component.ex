defmodule HealthWeb.MealsComponent do
  @moduledoc """
  Component for viewing daily and weekly routine (rhythms).
  """
  use HealthWeb, :live_component

  alias Health.Nutrition
  alias Health.Nutrition.Rhythm

  @impl true
  def mount(socket) do
    today = Date.utc_today()

    {:ok,
     socket
     |> assign(selected_date: today)
     |> assign(view_mode: :day)
     |> assign(expanded_rhythm_ids: MapSet.new())
     |> assign(editing_notes_id: nil)}
  end

  @impl true
  def update(assigns, socket) do
    date = socket.assigns[:selected_date] || Date.utc_today()
    rhythms = Nutrition.list_rhythms_by_date(date)

    # Get week range for week view
    start_of_week = Date.beginning_of_week(date, :monday)
    end_of_week = Date.end_of_week(date, :monday)
    week_rhythms = Nutrition.list_rhythms_by_date_range(start_of_week, end_of_week)

    socket =
      socket
      |> assign(assigns)
      |> assign(rhythms: rhythms)
      |> assign(week_rhythms: week_rhythms)
      |> assign(start_of_week: start_of_week)
      |> assign(end_of_week: end_of_week)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    date = Date.from_iso8601!(date_string)
    rhythms = Nutrition.list_rhythms_by_date(date)

    start_of_week = Date.beginning_of_week(date, :monday)
    end_of_week = Date.end_of_week(date, :monday)
    week_rhythms = Nutrition.list_rhythms_by_date_range(start_of_week, end_of_week)

    {:noreply,
     socket
     |> assign(selected_date: date)
     |> assign(rhythms: rhythms)
     |> assign(week_rhythms: week_rhythms)
     |> assign(start_of_week: start_of_week)
     |> assign(end_of_week: end_of_week)}
  end

  @impl true
  def handle_event("prev_day", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, -1)
    handle_event("select_date", %{"date" => Date.to_iso8601(new_date)}, socket)
  end

  @impl true
  def handle_event("next_day", _params, socket) do
    new_date = Date.add(socket.assigns.selected_date, 1)
    handle_event("select_date", %{"date" => Date.to_iso8601(new_date)}, socket)
  end

  @impl true
  def handle_event("today", _params, socket) do
    handle_event("select_date", %{"date" => Date.to_iso8601(Date.utc_today())}, socket)
  end

  @impl true
  def handle_event("toggle_view", _params, socket) do
    new_mode = if socket.assigns.view_mode == :day, do: :week, else: :day
    {:noreply, assign(socket, view_mode: new_mode)}
  end

  @impl true
  def handle_event("view_rhythm_day", %{"date" => date_string}, socket) do
    date = Date.from_iso8601!(date_string)
    rhythms = Nutrition.list_rhythms_by_date(date)

    {:noreply,
     socket
     |> assign(selected_date: date)
     |> assign(rhythms: rhythms)
     |> assign(view_mode: :day)}
  end

  @impl true
  def handle_event("mark_completed", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.mark_rhythm_completed(rhythm)
    refresh_rhythms(socket)
  end

  @impl true
  def handle_event("mark_skipped", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.mark_rhythm_skipped(rhythm)
    refresh_rhythms(socket)
  end

  @impl true
  def handle_event("reset_status", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.reset_rhythm_status(rhythm)
    refresh_rhythms(socket)
  end

  @impl true
  def handle_event("toggle_notes", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = socket.assigns.expanded_rhythm_ids

    new_expanded =
      if MapSet.member?(expanded, id) do
        MapSet.delete(expanded, id)
      else
        MapSet.put(expanded, id)
      end

    {:noreply, assign(socket, expanded_rhythm_ids: new_expanded, editing_notes_id: nil)}
  end

  @impl true
  def handle_event("edit_notes", %{"id" => id}, socket) do
    {:noreply, assign(socket, editing_notes_id: String.to_integer(id))}
  end

  @impl true
  def handle_event("cancel_edit_notes", _params, socket) do
    {:noreply, assign(socket, editing_notes_id: nil)}
  end

  @impl true
  def handle_event("save_notes", %{"rhythm_id" => id, "notes" => notes}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.update_rhythm(rhythm, %{notes: notes})

    socket = assign(socket, editing_notes_id: nil)
    refresh_rhythms(socket)
  end

  defp refresh_rhythms(socket) do
    date = socket.assigns.selected_date
    rhythms = Nutrition.list_rhythms_by_date(date)

    start_of_week = socket.assigns.start_of_week
    end_of_week = socket.assigns.end_of_week
    week_rhythms = Nutrition.list_rhythms_by_date_range(start_of_week, end_of_week)

    {:noreply, assign(socket, rhythms: rhythms, week_rhythms: week_rhythms)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4 sm:space-y-6">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-xl sm:text-2xl font-bold text-white">Daily Routine</h2>
        <button
          phx-click="toggle_view"
          phx-target={@myself}
          class="px-3 py-1.5 sm:px-4 sm:py-2 rounded-lg bg-purple-500/20 text-purple-300 hover:bg-purple-500/30 transition-colors flex items-center gap-1.5 sm:gap-2 text-sm sm:text-base"
        >
          <.icon name={if @view_mode == :day, do: "hero-calendar-days", else: "hero-calendar"} class="w-4 h-4 sm:w-5 sm:h-5" />
          <span class="hidden xs:inline">{if @view_mode == :day, do: "Week", else: "Day"}</span>
        </button>
      </div>

      <div class="cosmic-card p-3 sm:p-4 rounded-2xl">
        <!-- Mobile: Stacked layout -->
        <div class="flex flex-col gap-3 sm:hidden">
          <div class="flex items-center justify-between">
            <button
              phx-click="prev_day"
              phx-target={@myself}
              class="p-2.5 text-purple-300 hover:text-white bg-purple-500/10 hover:bg-purple-500/20 rounded-lg transition-colors"
            >
              <.icon name="hero-chevron-left" class="w-5 h-5" />
            </button>

            <div class="text-center">
              <p class="text-base font-medium text-purple-200">{format_short_date(@selected_date)}</p>
              <p :if={Date.compare(@selected_date, Date.utc_today()) == :eq} class="text-xs text-emerald-400">
                Today
              </p>
            </div>

            <button
              phx-click="next_day"
              phx-target={@myself}
              class="p-2.5 text-purple-300 hover:text-white bg-purple-500/10 hover:bg-purple-500/20 rounded-lg transition-colors"
            >
              <.icon name="hero-chevron-right" class="w-5 h-5" />
            </button>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="date"
              value={Date.to_iso8601(@selected_date)}
              phx-change="select_date"
              phx-target={@myself}
              name="date"
              class="flex-1 px-3 py-2 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white text-sm focus:outline-none focus:border-purple-400"
            />
            <button
              phx-click="today"
              phx-target={@myself}
              class="px-3 py-2 text-sm rounded-lg bg-purple-500/20 text-purple-300 hover:bg-purple-500/30 transition-colors whitespace-nowrap"
            >
              Today
            </button>
          </div>
        </div>

        <!-- Desktop: Original horizontal layout -->
        <div class="hidden sm:block">
          <div class="flex items-center justify-between mb-4">
            <button
              phx-click="prev_day"
              phx-target={@myself}
              class="p-2 text-purple-300 hover:text-white hover:bg-purple-500/20 rounded-lg transition-colors"
            >
              <.icon name="hero-chevron-left" class="w-5 h-5" />
            </button>

            <div class="flex items-center gap-4">
              <input
                type="date"
                value={Date.to_iso8601(@selected_date)}
                phx-change="select_date"
                phx-target={@myself}
                name="date"
                class="px-4 py-2 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
              />
              <button
                phx-click="today"
                phx-target={@myself}
                class="px-3 py-2 text-sm rounded-lg bg-purple-500/20 text-purple-300 hover:bg-purple-500/30 transition-colors"
              >
                Today
              </button>
            </div>

            <button
              phx-click="next_day"
              phx-target={@myself}
              class="p-2 text-purple-300 hover:text-white hover:bg-purple-500/20 rounded-lg transition-colors"
            >
              <.icon name="hero-chevron-right" class="w-5 h-5" />
            </button>
          </div>

          <div class="text-center text-purple-200 mb-6">
            <p class="text-lg font-medium">{format_full_date(@selected_date)}</p>
            <p :if={Date.compare(@selected_date, Date.utc_today()) == :eq} class="text-sm text-emerald-400">
              Today
            </p>
          </div>
        </div>
      </div>

      <%= if @view_mode == :day do %>
        <.day_view
          rhythms={@rhythms}
          myself={@myself}
          expanded_rhythm_ids={@expanded_rhythm_ids}
          editing_notes_id={@editing_notes_id}
        />
      <% else %>
        <.week_view
          week_rhythms={@week_rhythms}
          start_of_week={@start_of_week}
          end_of_week={@end_of_week}
          selected_date={@selected_date}
          myself={@myself}
        />
      <% end %>
    </div>
    """
  end

  defp day_view(assigns) do
    ~H"""
    <div class="cosmic-card p-3 sm:p-6 rounded-2xl">
      <div :if={@rhythms == []} class="text-center py-8 sm:py-12">
        <.icon name="hero-calendar" class="w-12 h-12 sm:w-16 sm:h-16 mx-auto text-purple-400 opacity-50 mb-4" />
        <h3 class="text-lg sm:text-xl text-white mb-2">No Routine Scheduled</h3>
        <p class="text-purple-300 text-sm sm:text-base">No activities are scheduled for this date.</p>
        <p class="text-purple-400 text-xs sm:text-sm mt-2">
          Create an orbit to add rhythms to your routine.
        </p>
      </div>

      <div :if={@rhythms != []} class="space-y-3">
        <%= for rhythm <- Enum.sort_by(@rhythms, &Rhythm.rhythm_order(&1.meal_type)) do %>
          <% is_expanded = MapSet.member?(@expanded_rhythm_ids, rhythm.id) %>
          <% is_editing = @editing_notes_id == rhythm.id %>
          <% has_notes = rhythm.notes && rhythm.notes != "" %>
          <% was_updated = rhythm.updated_at != rhythm.inserted_at %>

          <div class={"p-3 sm:p-4 rounded-xl #{rhythm_bg(rhythm.status)}"}>
            <!-- Mobile layout -->
            <div class="sm:hidden">
              <div class="flex items-start justify-between gap-2 mb-2">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 flex-wrap mb-1">
                    <span class={"px-2 py-0.5 rounded text-xs font-medium #{type_badge_class(rhythm.meal_type)}"}>
                      {Rhythm.rhythm_display(rhythm.meal_type)}
                    </span>
                    <span class={"px-2 py-0.5 rounded text-xs font-medium #{status_badge(rhythm.status)}"}>
                      {rhythm.status |> String.capitalize()}
                    </span>
                    <span :if={was_updated} class="flex items-center gap-0.5 px-1.5 py-0.5 rounded bg-cyan-500/20 text-cyan-300 text-xs">
                      <.icon name="hero-pencil-square" class="w-3 h-3" />
                    </span>
                  </div>
                  <p class="text-white font-medium text-sm truncate">{rhythm.name}</p>
                  <p :if={rhythm.orbit} class="text-purple-500 text-xs truncate">
                    from {rhythm.orbit.name}
                  </p>
                </div>
                <button
                  phx-click="toggle_notes"
                  phx-target={@myself}
                  phx-value-id={rhythm.id}
                  class={"p-2 rounded-lg transition-colors #{if has_notes, do: "text-purple-300 bg-purple-500/10", else: "text-purple-500"}"}
                >
                  <.icon name={if is_expanded, do: "hero-chevron-up", else: "hero-chevron-down"} class="w-5 h-5" />
                </button>
              </div>
              <div class="flex items-center justify-end gap-1 pt-2 border-t border-purple-500/10">
                <button
                  :if={rhythm.status != "completed"}
                  phx-click="mark_completed"
                  phx-target={@myself}
                  phx-value-id={rhythm.id}
                  class="flex items-center gap-1 px-3 py-1.5 text-xs text-emerald-400 bg-emerald-500/10 hover:bg-emerald-500/20 rounded-lg transition-colors"
                >
                  <.icon name="hero-check-circle" class="w-4 h-4" />
                  <span>Done</span>
                </button>
                <button
                  :if={rhythm.status != "skipped"}
                  phx-click="mark_skipped"
                  phx-target={@myself}
                  phx-value-id={rhythm.id}
                  class="flex items-center gap-1 px-3 py-1.5 text-xs text-red-400 bg-red-500/10 hover:bg-red-500/20 rounded-lg transition-colors"
                >
                  <.icon name="hero-x-circle" class="w-4 h-4" />
                  <span>Skip</span>
                </button>
                <button
                  :if={rhythm.status != "pending"}
                  phx-click="reset_status"
                  phx-target={@myself}
                  phx-value-id={rhythm.id}
                  class="flex items-center gap-1 px-3 py-1.5 text-xs text-yellow-400 bg-yellow-500/10 hover:bg-yellow-500/20 rounded-lg transition-colors"
                >
                  <.icon name="hero-arrow-path" class="w-4 h-4" />
                  <span>Reset</span>
                </button>
              </div>
            </div>

            <!-- Desktop layout -->
            <div class="hidden sm:flex items-center justify-between">
              <div class="flex items-center gap-3">
                <span class={"px-2 py-1 rounded text-xs font-medium #{type_badge_class(rhythm.meal_type)}"}>
                  {Rhythm.rhythm_display(rhythm.meal_type)}
                </span>
                <div>
                  <div class="flex items-center gap-2">
                    <p class="text-white font-medium">{rhythm.name}</p>
                    <span :if={was_updated} class="flex items-center gap-1 px-1.5 py-0.5 rounded bg-cyan-500/20 text-cyan-300 text-xs" title="Notes updated">
                      <.icon name="hero-pencil-square" class="w-3 h-3" />
                      updated
                    </span>
                  </div>
                  <div class="flex items-center gap-3 text-sm text-purple-400">
                    <span :if={rhythm.scheduled_time}>at {format_time(rhythm.scheduled_time)}</span>
                    <span :if={rhythm.orbit} class="text-purple-500">
                      from {rhythm.orbit.name}
                    </span>
                  </div>
                </div>
              </div>

              <div class="flex items-center gap-2">
                <button
                  phx-click="toggle_notes"
                  phx-target={@myself}
                  phx-value-id={rhythm.id}
                  class={"p-1.5 rounded transition-colors #{if has_notes, do: "text-purple-300 hover:bg-purple-500/20", else: "text-purple-500 hover:bg-purple-500/20"}"}
                  title={if is_expanded, do: "Hide notes", else: "Show notes"}
                >
                  <.icon name={if is_expanded, do: "hero-chevron-up", else: "hero-chevron-down"} class="w-5 h-5" />
                </button>

                <span class={"px-2 py-1 rounded text-xs font-medium #{status_badge(rhythm.status)}"}>
                  {rhythm.status |> String.capitalize()}
                </span>

                <div class="flex items-center">
                  <button
                    :if={rhythm.status != "completed"}
                    phx-click="mark_completed"
                    phx-target={@myself}
                    phx-value-id={rhythm.id}
                    class="p-1.5 text-emerald-400 hover:bg-emerald-500/20 rounded transition-colors"
                    title="Mark completed"
                  >
                    <.icon name="hero-check-circle" class="w-5 h-5" />
                  </button>
                  <button
                    :if={rhythm.status != "skipped"}
                    phx-click="mark_skipped"
                    phx-target={@myself}
                    phx-value-id={rhythm.id}
                    class="p-1.5 text-red-400 hover:bg-red-500/20 rounded transition-colors"
                    title="Mark skipped"
                  >
                    <.icon name="hero-x-circle" class="w-5 h-5" />
                  </button>
                  <button
                    :if={rhythm.status != "pending"}
                    phx-click="reset_status"
                    phx-target={@myself}
                    phx-value-id={rhythm.id}
                    class="p-1.5 text-yellow-400 hover:bg-yellow-500/20 rounded transition-colors"
                    title="Reset"
                  >
                    <.icon name="hero-arrow-path" class="w-5 h-5" />
                  </button>
                </div>
              </div>
            </div>

            <%= if is_expanded do %>
              <div class="mt-3 pt-3 border-t border-purple-500/20">
                <%= if is_editing do %>
                  <form phx-submit="save_notes" phx-target={@myself}>
                    <input type="hidden" name="rhythm_id" value={rhythm.id} />
                    <textarea
                      name="notes"
                      rows="4"
                      placeholder="Add notes or instructions for this routine..."
                      class="w-full px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
                    >{rhythm.notes}</textarea>
                    <div class="flex gap-2 mt-2">
                      <button
                        type="submit"
                        class="px-3 py-1.5 text-sm rounded-lg bg-purple-500 text-white hover:bg-purple-600 transition-colors"
                      >
                        Save
                      </button>
                      <button
                        type="button"
                        phx-click="cancel_edit_notes"
                        phx-target={@myself}
                        class="px-3 py-1.5 text-sm rounded-lg text-purple-300 hover:text-white border border-purple-500/30 hover:border-purple-400 transition-colors"
                      >
                        Cancel
                      </button>
                    </div>
                  </form>
                <% else %>
                  <div class="flex items-start justify-between gap-3">
                    <div class="flex-1">
                      <%= if has_notes do %>
                        <div class="text-sm text-purple-200 whitespace-pre-wrap">{rhythm.notes}</div>
                      <% else %>
                        <p class="text-sm text-purple-400 italic">No notes added yet.</p>
                      <% end %>
                    </div>
                    <button
                      phx-click="edit_notes"
                      phx-target={@myself}
                      phx-value-id={rhythm.id}
                      class="p-1.5 text-purple-300 hover:bg-purple-500/20 rounded transition-colors shrink-0"
                      title="Edit notes"
                    >
                      <.icon name="hero-pencil" class="w-4 h-4" />
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp week_view(assigns) do
    days = Date.range(assigns.start_of_week, assigns.end_of_week) |> Enum.to_list()

    # Calculate stats for each day
    day_stats =
      Enum.map(days, fn day ->
        rhythms = Map.get(assigns.week_rhythms, day, [])
        total = length(rhythms)
        completed = Enum.count(rhythms, &(&1.status == "completed"))
        skipped = Enum.count(rhythms, &(&1.status == "skipped"))
        pending = Enum.count(rhythms, &(&1.status == "pending"))
        percentage = if total > 0, do: round(completed / total * 100), else: 0

        {day, %{rhythms: rhythms, total: total, completed: completed, skipped: skipped, pending: pending, percentage: percentage}}
      end)

    assigns = assign(assigns, days: days, day_stats: Map.new(day_stats))

    ~H"""
    <div class="cosmic-card p-3 sm:p-6 rounded-2xl">
      <!-- Mobile: Compact vertical list -->
      <div class="sm:hidden space-y-2">
        <button
          :for={day <- @days}
          phx-click="view_rhythm_day"
          phx-target={@myself}
          phx-value-date={Date.to_iso8601(day)}
          class={"flex items-center justify-between p-3 rounded-xl w-full transition-all #{day_card_class(day, @selected_date, @day_stats[day])}"}
        >
          <div class="flex items-center gap-3">
            <div class="text-center min-w-[40px]">
              <p class="text-xs text-purple-400">{day_name(day)}</p>
              <p class="text-lg font-bold text-white">{day.day}</p>
            </div>
            <%= if @day_stats[day].total > 0 do %>
              <div class="flex items-center gap-1">
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400" :for={_ <- 1..min(@day_stats[day].completed, 5)//1} />
                <span class="w-1.5 h-1.5 rounded-full bg-red-400" :for={_ <- 1..min(@day_stats[day].skipped, 5)//1} />
                <span class="w-1.5 h-1.5 rounded-full bg-yellow-400" :for={_ <- 1..min(@day_stats[day].pending, 5)//1} />
              </div>
            <% end %>
          </div>
          <div class="flex items-center gap-3">
            <%= if @day_stats[day].total > 0 do %>
              <div class="text-right">
                <div class="text-lg font-bold" style={"color: #{percentage_color(@day_stats[day].percentage)}"}>
                  {@day_stats[day].percentage}%
                </div>
                <div class="text-xs text-purple-400">
                  {@day_stats[day].completed}/{@day_stats[day].total}
                </div>
              </div>
            <% else %>
              <span class="text-purple-500 text-xs">No tasks</span>
            <% end %>
            <.icon name="hero-chevron-right" class="w-4 h-4 text-purple-400" />
          </div>
        </button>
      </div>

      <!-- Desktop: Grid view -->
      <div class="hidden sm:block overflow-x-auto">
        <div class="grid grid-cols-7 gap-3 min-w-[700px]">
          <div :for={day <- @days} class="text-center">
            <button
              phx-click="view_rhythm_day"
              phx-target={@myself}
              phx-value-date={Date.to_iso8601(day)}
              class={"p-3 rounded-xl w-full transition-all hover:scale-105 cursor-pointer #{day_card_class(day, @selected_date, @day_stats[day])}"}
            >
              <p class="text-xs text-purple-400 mb-1">{day_name(day)}</p>
              <p class="text-xl font-bold mb-2">{day.day}</p>

              <%= if @day_stats[day].total > 0 do %>
                <div class="space-y-2">
                  <div class="text-2xl font-bold" style={"color: #{percentage_color(@day_stats[day].percentage)}"}>
                    {@day_stats[day].percentage}%
                  </div>
                  <div class="text-xs text-purple-300">
                    {@day_stats[day].completed}/{@day_stats[day].total} done
                  </div>
                  <div class="flex justify-center gap-1 mt-2">
                    <span class="w-2 h-2 rounded-full bg-emerald-400" title={"#{@day_stats[day].completed} completed"} :for={_ <- 1..max(@day_stats[day].completed, 0)//1} />
                    <span class="w-2 h-2 rounded-full bg-red-400" title={"#{@day_stats[day].skipped} skipped"} :for={_ <- 1..max(@day_stats[day].skipped, 0)//1} />
                    <span class="w-2 h-2 rounded-full bg-yellow-400" title={"#{@day_stats[day].pending} pending"} :for={_ <- 1..max(@day_stats[day].pending, 0)//1} />
                  </div>
                </div>
              <% else %>
                <div class="text-purple-400 text-xs mt-2">No activities</div>
              <% end %>
            </button>
          </div>
        </div>
      </div>

      <div class="mt-4 flex justify-center gap-4 sm:gap-6 text-xs text-purple-300">
        <span class="flex items-center gap-1"><span class="w-2 h-2 rounded-full bg-emerald-400"></span> Done</span>
        <span class="flex items-center gap-1"><span class="w-2 h-2 rounded-full bg-red-400"></span> Skipped</span>
        <span class="flex items-center gap-1"><span class="w-2 h-2 rounded-full bg-yellow-400"></span> Pending</span>
      </div>
    </div>
    """
  end

  defp day_card_class(day, selected_date, stats) do
    base = cond do
      Date.compare(day, selected_date) == :eq ->
        "bg-purple-500/40 border-2 border-purple-400"
      Date.compare(day, Date.utc_today()) == :eq ->
        "bg-purple-500/20 border border-purple-400/50"
      true ->
        "bg-purple-900/30 border border-purple-500/20"
    end

    # Add color indicator based on completion
    if stats.total > 0 do
      cond do
        stats.percentage == 100 -> "#{base} ring-2 ring-emerald-400/50"
        stats.skipped > 0 -> "#{base} ring-2 ring-red-400/30"
        true -> base
      end
    else
      base
    end
  end

  defp percentage_color(percentage) when percentage >= 80, do: "#4ade80"  # emerald
  defp percentage_color(percentage) when percentage >= 50, do: "#facc15"  # yellow
  defp percentage_color(_), do: "#f87171"  # red

  defp type_badge_class("dawn"), do: "bg-pink-500/30 text-pink-300"
  defp type_badge_class("morning"), do: "bg-amber-500/30 text-amber-300"
  defp type_badge_class("midday"), do: "bg-yellow-500/30 text-yellow-300"
  defp type_badge_class("afternoon"), do: "bg-orange-500/30 text-orange-300"
  defp type_badge_class("evening"), do: "bg-rose-500/30 text-rose-300"
  defp type_badge_class("night"), do: "bg-indigo-500/30 text-indigo-300"
  defp type_badge_class("late_night"), do: "bg-purple-500/30 text-purple-300"
  defp type_badge_class(_), do: "bg-purple-500/30 text-purple-300"

  defp rhythm_bg("completed"), do: "bg-emerald-900/20 border border-emerald-500/30"
  defp rhythm_bg("skipped"), do: "bg-red-900/20 border border-red-500/30"
  defp rhythm_bg(_), do: "bg-purple-900/20 border border-purple-500/30"

  defp status_badge("completed"), do: "bg-emerald-500/20 text-emerald-300"
  defp status_badge("skipped"), do: "bg-red-500/20 text-red-300"
  defp status_badge(_), do: "bg-yellow-500/20 text-yellow-300"

  defp day_name(date) do
    Calendar.strftime(date, "%a")
  end

  defp format_full_date(date) do
    Calendar.strftime(date, "%A, %B %d, %Y")
  end

  defp format_short_date(date) do
    Calendar.strftime(date, "%a, %b %d")
  end

  defp format_time(time) do
    Calendar.strftime(time, "%H:%M")
  end
end
