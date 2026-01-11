defmodule HealthWeb.OrbitsComponent do
  @moduledoc """
  Component for managing Orbits (practice plans) and their Rhythms (daily activities).
  """
  use HealthWeb, :live_component

  alias Health.Nutrition
  alias Health.Nutrition.{Orbit, Rhythm}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(view: :list)
     |> assign(selected_orbit: nil)
     |> assign(editing_orbit: nil)
     |> assign(adding_rhythm: false)
     |> assign(selected_date: Date.utc_today())
     |> assign(rhythm_entries: default_rhythm_entries())
     |> assign(expanded_rhythm_ids: MapSet.new())}
  end

  defp default_rhythm_entries do
    # Default entries with name, type, and notes
    [
      %{id: 1, name: "Morning practice", type: "morning", notes: ""},
      %{id: 2, name: "Evening practice", type: "evening", notes: ""}
    ]
  end

  @impl true
  def update(assigns, socket) do
    orbits = Nutrition.list_orbits()

    socket =
      socket
      |> assign(assigns)
      |> assign(orbits: orbits)
      |> assign_orbit_form(Nutrition.change_orbit(%Orbit{}))
      |> assign_rhythm_form(Nutrition.change_rhythm(%Rhythm{}))

    socket =
      if socket.assigns.selected_orbit do
        orbit = Nutrition.get_orbit_with_rhythms!(socket.assigns.selected_orbit.id)
        assign(socket, selected_orbit: orbit)
      else
        socket
      end

    {:ok, socket}
  end

  defp assign_orbit_form(socket, changeset) do
    assign(socket, :orbit_form, to_form(changeset))
  end

  defp assign_rhythm_form(socket, changeset) do
    assign(socket, :rhythm_form, to_form(changeset))
  end

  # Navigation
  @impl true
  def handle_event("new_orbit", _params, socket) do
    {:noreply,
     socket
     |> assign(view: :new)
     |> assign(editing_orbit: nil)
     |> assign(rhythm_entries: default_rhythm_entries())
     |> assign_orbit_form(Nutrition.change_orbit(%Orbit{start_date: Date.utc_today()}))}
  end

  @impl true
  def handle_event("view_orbit", %{"id" => id}, socket) do
    orbit = Nutrition.get_orbit_with_rhythms!(id)

    {:noreply,
     socket
     |> assign(view: :detail)
     |> assign(selected_orbit: orbit)
     |> assign(adding_rhythm: false)}
  end

  @impl true
  def handle_event("edit_orbit", %{"id" => id}, socket) do
    orbit = Nutrition.get_orbit!(id)

    {:noreply,
     socket
     |> assign(view: :edit)
     |> assign(editing_orbit: orbit)
     |> assign_orbit_form(Nutrition.change_orbit(orbit))}
  end

  @impl true
  def handle_event("back_to_list", _params, socket) do
    {:noreply,
     socket
     |> assign(view: :list)
     |> assign(selected_orbit: nil)
     |> assign(editing_orbit: nil)
     |> assign(adding_rhythm: false)
     |> assign(orbits: Nutrition.list_orbits())}
  end

  # Rhythm entry management for new orbit form
  @impl true
  def handle_event("add_rhythm_entry", _params, socket) do
    entries = socket.assigns.rhythm_entries
    new_id = (Enum.map(entries, & &1.id) |> Enum.max(fn -> 0 end)) + 1
    new_entry = %{id: new_id, name: "", type: "morning", notes: ""}

    {:noreply, assign(socket, rhythm_entries: entries ++ [new_entry])}
  end

  @impl true
  def handle_event("remove_rhythm_entry", %{"id" => id}, socket) do
    id = String.to_integer(id)
    entries = Enum.reject(socket.assigns.rhythm_entries, &(&1.id == id))

    {:noreply, assign(socket, rhythm_entries: entries)}
  end

  @impl true
  def handle_event("update_rhythm_name", params, socket) do
    # Extract the id and value from the rhythm_name_* key in params
    {id, value} =
      params
      |> Enum.find(fn {key, _val} -> String.starts_with?(key, "rhythm_name_") end)
      |> case do
        {"rhythm_name_" <> id_string, value} -> {String.to_integer(id_string), value}
        _ -> {nil, nil}
      end

    if id do
      entries = Enum.map(socket.assigns.rhythm_entries, fn entry ->
        if entry.id == id, do: %{entry | name: value}, else: entry
      end)

      {:noreply, assign(socket, rhythm_entries: entries)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_rhythm_type", params, socket) do
    # Extract the id and type from the rhythm_type_* key in params
    {id, type} =
      params
      |> Enum.find(fn {key, _val} -> String.starts_with?(key, "rhythm_type_") end)
      |> case do
        {"rhythm_type_" <> id_string, type} -> {String.to_integer(id_string), type}
        _ -> {nil, nil}
      end

    if id do
      entries = Enum.map(socket.assigns.rhythm_entries, fn entry ->
        if entry.id == id, do: %{entry | type: type}, else: entry
      end)

      {:noreply, assign(socket, rhythm_entries: entries)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_rhythm_notes", params, socket) do
    # Extract the id and notes from the rhythm_notes_* key in params
    {id, notes} =
      params
      |> Enum.find(fn {key, _val} -> String.starts_with?(key, "rhythm_notes_") end)
      |> case do
        {"rhythm_notes_" <> id_string, notes} -> {String.to_integer(id_string), notes}
        _ -> {nil, nil}
      end

    if id do
      entries = Enum.map(socket.assigns.rhythm_entries, fn entry ->
        if entry.id == id, do: %{entry | notes: notes}, else: entry
      end)

      {:noreply, assign(socket, rhythm_entries: entries)}
    else
      {:noreply, socket}
    end
  end

  # Orbit CRUD
  @impl true
  def handle_event("validate_orbit", %{"orbit" => params}, socket) do
    orbit = socket.assigns.editing_orbit || %Orbit{}

    changeset =
      orbit
      |> Nutrition.change_orbit(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_orbit_form(socket, changeset)}
  end

  @impl true
  def handle_event("save_orbit", %{"orbit" => params}, socket) do
    save_orbit(socket, socket.assigns.editing_orbit, params)
  end

  @impl true
  def handle_event("delete_orbit", %{"id" => id}, socket) do
    orbit = Nutrition.get_orbit!(id)
    {:ok, _} = Nutrition.delete_orbit(orbit)

    {:noreply,
     socket
     |> assign(view: :list)
     |> assign(selected_orbit: nil)
     |> assign(orbits: Nutrition.list_orbits())}
  end

  # Rhythm management
  @impl true
  def handle_event("show_add_rhythm", _params, socket) do
    {:noreply,
     socket
     |> assign(adding_rhythm: true)
     |> assign_rhythm_form(Nutrition.change_rhythm(%Rhythm{scheduled_date: socket.assigns.selected_date}))}
  end

  @impl true
  def handle_event("cancel_add_rhythm", _params, socket) do
    {:noreply, assign(socket, adding_rhythm: false)}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    date = Date.from_iso8601!(date_string)
    {:noreply, assign(socket, selected_date: date)}
  end

  @impl true
  def handle_event("validate_rhythm", %{"rhythm" => params}, socket) do
    changeset =
      %Rhythm{}
      |> Nutrition.change_rhythm(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_rhythm_form(socket, changeset)}
  end

  @impl true
  def handle_event("save_rhythm", %{"rhythm" => params}, socket) do
    params =
      params
      |> Map.put("diet_plan_id", socket.assigns.selected_orbit.id)
      |> Map.put("scheduled_date", Date.to_iso8601(socket.assigns.selected_date))

    case Nutrition.create_rhythm(params) do
      {:ok, _rhythm} ->
        orbit = Nutrition.get_orbit_with_rhythms!(socket.assigns.selected_orbit.id)

        {:noreply,
         socket
         |> assign(selected_orbit: orbit)
         |> assign(adding_rhythm: false)
         |> assign_rhythm_form(Nutrition.change_rhythm(%Rhythm{}))}

      {:error, changeset} ->
        {:noreply, assign_rhythm_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("delete_rhythm", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.delete_rhythm(rhythm)

    orbit = Nutrition.get_orbit_with_rhythms!(socket.assigns.selected_orbit.id)
    {:noreply, assign(socket, selected_orbit: orbit)}
  end

  @impl true
  def handle_event("mark_completed", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.mark_rhythm_completed(rhythm)

    orbit = Nutrition.get_orbit_with_rhythms!(socket.assigns.selected_orbit.id)
    {:noreply, assign(socket, selected_orbit: orbit)}
  end

  @impl true
  def handle_event("mark_skipped", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.mark_rhythm_skipped(rhythm)

    orbit = Nutrition.get_orbit_with_rhythms!(socket.assigns.selected_orbit.id)
    {:noreply, assign(socket, selected_orbit: orbit)}
  end

  @impl true
  def handle_event("reset_status", %{"id" => id}, socket) do
    rhythm = Nutrition.get_rhythm!(id)
    {:ok, _} = Nutrition.reset_rhythm_status(rhythm)

    orbit = Nutrition.get_orbit_with_rhythms!(socket.assigns.selected_orbit.id)
    {:noreply, assign(socket, selected_orbit: orbit)}
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

    {:noreply, assign(socket, expanded_rhythm_ids: new_expanded)}
  end

  defp save_orbit(socket, nil, params) do
    rhythm_entries = socket.assigns.rhythm_entries
    valid_entries = Enum.filter(rhythm_entries, fn entry -> entry.name != "" end)

    if valid_entries == [] do
      {:noreply, socket |> put_flash(:error, "Please add at least one rhythm with a name")}
    else
      case Nutrition.create_orbit_with_custom_rhythms(params, valid_entries) do
        {:ok, orbit} ->
          {:noreply,
           socket
           |> assign(view: :detail)
           |> assign(selected_orbit: orbit)
           |> assign(orbits: Nutrition.list_orbits())}

        {:error, changeset} ->
          {:noreply, assign_orbit_form(socket, changeset)}
      end
    end
  end

  defp save_orbit(socket, orbit, params) do
    case Nutrition.update_orbit(orbit, params) do
      {:ok, updated_orbit} ->
        orbit = Nutrition.get_orbit_with_rhythms!(updated_orbit.id)

        {:noreply,
         socket
         |> assign(view: :detail)
         |> assign(selected_orbit: orbit)
         |> assign(editing_orbit: nil)
         |> assign(orbits: Nutrition.list_orbits())}

      {:error, changeset} ->
        {:noreply, assign_orbit_form(socket, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= case @view do %>
        <% :list -> %>
          <.orbit_list {assigns} />
        <% :new -> %>
          <.orbit_form {assigns} title="Create New Orbit" />
        <% :edit -> %>
          <.orbit_form {assigns} title="Edit Orbit" />
        <% :detail -> %>
          <.orbit_detail {assigns} />
      <% end %>
    </div>
    """
  end

  defp orbit_list(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <h2 class="text-2xl font-bold text-white">Your Orbits</h2>
      <button
        phx-click="new_orbit"
        phx-target={@myself}
        class="cosmic-button px-4 py-2 rounded-lg font-medium flex items-center gap-2"
      >
        <.icon name="hero-plus" class="w-5 h-5" />
        New Orbit
      </button>
    </div>

    <div :if={@orbits == []} class="cosmic-card p-12 rounded-2xl text-center">
      <.icon name="hero-sparkles" class="w-16 h-16 mx-auto text-purple-400 opacity-50 mb-4" />
      <h3 class="text-xl text-white mb-2">No Orbits Yet</h3>
      <p class="text-purple-300 mb-6">Create your first orbit to start tracking your daily rhythms and practices.</p>
      <button
        phx-click="new_orbit"
        phx-target={@myself}
        class="cosmic-button px-6 py-3 rounded-lg font-medium"
      >
        Create Your First Orbit
      </button>
    </div>

    <div :if={@orbits != []} class="grid gap-4">
      <button
        :for={orbit <- @orbits}
        phx-click="view_orbit"
        phx-target={@myself}
        phx-value-id={orbit.id}
        class="cosmic-card p-6 rounded-2xl text-left hover:border-purple-400 transition-all cursor-pointer group"
      >
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-xl font-semibold text-white mb-1 group-hover:text-purple-300 transition-colors">
              {orbit.name}
            </h3>
            <p :if={orbit.description} class="text-purple-300 text-sm mb-3 line-clamp-2">
              {orbit.description}
            </p>
            <div class="flex items-center gap-4 text-sm text-purple-400">
              <div class="flex items-center gap-2">
                <.icon name="hero-calendar" class="w-4 h-4" />
                <span>{format_date(orbit.start_date)}</span>
              </div>
              <div :if={orbit.end_date} class="flex items-center gap-2">
                <span>to {format_date(orbit.end_date)}</span>
              </div>
            </div>
          </div>
          <.icon name="hero-chevron-right" class="w-6 h-6 text-purple-400 group-hover:text-purple-300 transition-colors" />
        </div>
      </button>
    </div>
    """
  end

  defp orbit_form(assigns) do
    ~H"""
    <div>
      <button
        phx-click="back_to_list"
        phx-target={@myself}
        class="flex items-center gap-2 text-purple-300 hover:text-white mb-6 transition-colors"
      >
        <.icon name="hero-arrow-left" class="w-5 h-5" />
        Back to Orbits
      </button>

      <div class="cosmic-card p-6 rounded-2xl">
        <h2 class="text-2xl font-bold text-white mb-6">{@title}</h2>

        <.form
          for={@orbit_form}
          phx-target={@myself}
          phx-change="validate_orbit"
          phx-submit="save_orbit"
          class="space-y-6"
        >
          <div>
            <label class="block text-purple-200 text-sm mb-2">Orbit Name *</label>
            <.input
              field={@orbit_form[:name]}
              type="text"
              placeholder="e.g., Morning Wellness Routine"
              class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
            />
          </div>

          <div>
            <label class="block text-purple-200 text-sm mb-2">Description</label>
            <.input
              field={@orbit_form[:description]}
              type="textarea"
              rows="4"
              placeholder="Brief description of this orbit..."
              class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-purple-200 text-sm mb-2">Start Date *</label>
              <.input
                field={@orbit_form[:start_date]}
                type="date"
                class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
              />
            </div>
            <div>
              <label class="block text-purple-200 text-sm mb-2">End Date</label>
              <.input
                field={@orbit_form[:end_date]}
                type="date"
                class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
              />
            </div>
          </div>

          <div :if={!@editing_orbit}>
            <div class="flex items-center justify-between mb-3">
              <div>
                <label class="block text-purple-200 text-sm">Rhythm Entries *</label>
                <p class="text-purple-400 text-xs">Add the rhythms you want to track in this orbit</p>
              </div>
              <button
                type="button"
                phx-click="add_rhythm_entry"
                phx-target={@myself}
                class="px-3 py-1.5 text-sm rounded-lg bg-purple-500/20 text-purple-300 hover:bg-purple-500/30 transition-colors flex items-center gap-1"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                Add
              </button>
            </div>

            <div class="space-y-3">
              <div
                :for={entry <- @rhythm_entries}
                class="p-3 rounded-lg bg-purple-900/20 border border-purple-500/20"
              >
                <div class="flex items-center gap-3 mb-2">
                  <input
                    type="text"
                    value={entry.name}
                    placeholder="Rhythm name..."
                    phx-change="update_rhythm_name"
                    phx-debounce="100"
                    phx-target={@myself}
                    name={"rhythm_name_#{entry.id}"}
                    class="flex-1 px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
                  />
                  <select
                    phx-change="update_rhythm_type"
                    phx-target={@myself}
                    phx-value-id={entry.id}
                    name={"rhythm_type_#{entry.id}"}
                    class="px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
                  >
                    <option :for={type <- Rhythm.rhythm_types()} value={type} selected={entry.type == type}>
                      {Rhythm.rhythm_display(type)}
                    </option>
                  </select>
                  <button
                    type="button"
                    phx-click="remove_rhythm_entry"
                    phx-target={@myself}
                    phx-value-id={entry.id}
                    class="p-1.5 text-red-400 hover:bg-red-500/20 rounded transition-colors"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
                <textarea
                  value={entry.notes}
                  placeholder="Notes/instructions for this rhythm..."
                  phx-change="update_rhythm_notes"
                  phx-debounce="100"
                  phx-target={@myself}
                  name={"rhythm_notes_#{entry.id}"}
                  rows="2"
                  class="w-full px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
                >{entry.notes}</textarea>
              </div>
            </div>

            <p :if={@rhythm_entries == []} class="text-center py-4 text-purple-400 text-sm">
              No rhythms added. Click "Add" to create your first rhythm.
            </p>
          </div>

          <div class="flex gap-3 pt-4">
            <button type="submit" class="cosmic-button px-6 py-2 rounded-lg font-medium">
              {if @editing_orbit, do: "Save Changes", else: "Create Orbit"}
            </button>
            <button
              type="button"
              phx-click="back_to_list"
              phx-target={@myself}
              class="px-6 py-2 rounded-lg font-medium text-purple-300 hover:text-white border border-purple-500/30 hover:border-purple-400 transition-colors"
            >
              Cancel
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp orbit_detail(assigns) do
    rhythms_by_date = assigns.selected_orbit.rhythms |> Enum.group_by(& &1.scheduled_date)
    stats = Nutrition.get_rhythm_stats(assigns.selected_orbit.id)
    assigns = assign(assigns, rhythms_by_date: rhythms_by_date, stats: stats)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <button
          phx-click="back_to_list"
          phx-target={@myself}
          class="flex items-center gap-2 text-purple-300 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="w-5 h-5" />
          Back to Orbits
        </button>

        <div class="flex items-center gap-2">
          <button
            phx-click="edit_orbit"
            phx-target={@myself}
            phx-value-id={@selected_orbit.id}
            class="p-2 text-purple-300 hover:text-white hover:bg-purple-500/20 rounded-lg transition-colors"
          >
            <.icon name="hero-pencil" class="w-5 h-5" />
          </button>
          <button
            phx-click="delete_orbit"
            phx-target={@myself}
            phx-value-id={@selected_orbit.id}
            data-confirm="Delete this orbit and all its rhythms?"
            class="p-2 text-red-400 hover:text-red-300 hover:bg-red-500/20 rounded-lg transition-colors"
          >
            <.icon name="hero-trash" class="w-5 h-5" />
          </button>
        </div>
      </div>

      <div class="cosmic-card p-6 rounded-2xl mb-6">
        <h2 class="text-2xl font-bold text-white mb-2">{@selected_orbit.name}</h2>
        <p :if={@selected_orbit.description} class="text-purple-300 mb-4">{@selected_orbit.description}</p>

        <div class="flex items-center gap-6 text-sm text-purple-400 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-calendar" class="w-4 h-4" />
            <span>{format_date(@selected_orbit.start_date)}</span>
            <span :if={@selected_orbit.end_date}>to {format_date(@selected_orbit.end_date)}</span>
          </div>
        </div>

        <div :if={@stats.total > 0} class="grid grid-cols-4 gap-4 pt-4 border-t border-purple-500/20">
          <div class="text-center">
            <p class="text-2xl font-bold text-white">{@stats.total}</p>
            <p class="text-purple-400 text-xs">Total</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-emerald-400">{@stats.completed}</p>
            <p class="text-purple-400 text-xs">Completed</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-red-400">{@stats.skipped}</p>
            <p class="text-purple-400 text-xs">Skipped</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-yellow-400">{@stats.pending}</p>
            <p class="text-purple-400 text-xs">Pending</p>
          </div>
        </div>
      </div>

      <div class="cosmic-card p-6 rounded-2xl">
        <div class="mb-6">
          <h3 class="text-lg font-semibold text-white">Rhythms</h3>
        </div>

        <div :if={@selected_orbit.rhythms == []} class="text-center py-8 text-purple-300">
          <.icon name="hero-sparkles" class="w-12 h-12 mx-auto opacity-50 mb-2" />
          <p>No rhythms added yet</p>
          <p class="text-sm text-purple-400">Select a date and add your first rhythm</p>
        </div>

        <div :if={@selected_orbit.rhythms != []} class="space-y-6">
          <%= for {date, rhythms} <- @rhythms_by_date |> Enum.sort_by(fn {d, _} -> d end, Date) do %>
            <div>
              <h4 class="text-sm font-medium text-purple-400 mb-3">
                {Calendar.strftime(date, "%A, %B %d, %Y")}
              </h4>
              <div class="space-y-2">
                <%= for rhythm <- Enum.sort_by(rhythms, &Rhythm.rhythm_order(&1.meal_type)) do %>
                  <% has_notes = rhythm.notes && rhythm.notes != "" %>

                  <div class={"p-3 rounded-lg #{rhythm_bg(rhythm.status)}"}>
                    <div class="flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <span class={"px-2 py-1 rounded text-xs font-medium #{type_badge_class(rhythm.meal_type)}"}>
                          {Rhythm.rhythm_display(rhythm.meal_type)}
                        </span>
                        <p class="text-white font-medium">{rhythm.name}</p>
                      </div>

                      <div class="flex items-center gap-2">
                        <span class={"px-2 py-1 rounded text-xs font-medium #{status_badge(rhythm.status)}"}>
                          {rhythm.status |> String.capitalize()}
                        </span>

                        <button
                          phx-click="delete_rhythm"
                          phx-target={@myself}
                          phx-value-id={rhythm.id}
                          data-confirm="Delete this rhythm?"
                          class="p-1.5 text-red-400 hover:bg-red-500/20 rounded transition-colors"
                          title="Delete"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>
                    </div>

                    <%= if has_notes do %>
                      <div class="mt-2 pt-2 border-t border-purple-500/20">
                        <p class="text-xs text-purple-400 mb-1">Notes:</p>
                        <div class="text-sm text-purple-200 whitespace-pre-wrap">{rhythm.notes}</div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp rhythm_type_options do
    [{"Select time", ""} | Enum.map(Rhythm.rhythm_types(), fn t -> {Rhythm.rhythm_display(t), t} end)]
  end

  defp type_badge_class("dawn"), do: "bg-pink-500/30 text-pink-300"
  defp type_badge_class("morning"), do: "bg-amber-500/30 text-amber-300"
  defp type_badge_class("midday"), do: "bg-yellow-500/30 text-yellow-300"
  defp type_badge_class("afternoon"), do: "bg-orange-500/30 text-orange-300"
  defp type_badge_class("evening"), do: "bg-rose-500/30 text-rose-300"
  defp type_badge_class("night"), do: "bg-indigo-500/30 text-indigo-300"
  defp type_badge_class("late_night"), do: "bg-purple-500/30 text-purple-300"
  defp type_badge_class(_), do: "bg-purple-500/30 text-purple-300"

  defp rhythm_bg("completed"), do: "bg-emerald-900/20 border border-emerald-500/20"
  defp rhythm_bg("skipped"), do: "bg-red-900/20 border border-red-500/20"
  defp rhythm_bg(_), do: "bg-purple-900/30 border border-purple-500/20"

  defp status_badge("completed"), do: "bg-emerald-500/20 text-emerald-300"
  defp status_badge("skipped"), do: "bg-red-500/20 text-red-300"
  defp status_badge(_), do: "bg-yellow-500/20 text-yellow-300"

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
end
