defmodule HealthWeb.DietPlansComponent do
  use HealthWeb, :live_component

  alias Health.Nutrition
  alias Health.Nutrition.{DietPlan, Meal}

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(view: :list)
     |> assign(selected_plan: nil)
     |> assign(editing_plan: nil)
     |> assign(adding_meal: false)
     |> assign(selected_date: Date.utc_today())}
  end

  @impl true
  def update(assigns, socket) do
    diet_plans = Nutrition.list_diet_plans()

    socket =
      socket
      |> assign(assigns)
      |> assign(diet_plans: diet_plans)
      |> assign_plan_form(Nutrition.change_diet_plan(%DietPlan{}))
      |> assign_meal_form(Nutrition.change_meal(%Meal{}))

    # Refresh selected plan if viewing one
    socket =
      if socket.assigns.selected_plan do
        plan = Nutrition.get_diet_plan_with_meals!(socket.assigns.selected_plan.id)
        assign(socket, selected_plan: plan)
      else
        socket
      end

    {:ok, socket}
  end

  defp assign_plan_form(socket, changeset) do
    assign(socket, :plan_form, to_form(changeset))
  end

  defp assign_meal_form(socket, changeset) do
    assign(socket, :meal_form, to_form(changeset))
  end

  # Navigation
  @impl true
  def handle_event("new_plan", _params, socket) do
    {:noreply,
     socket
     |> assign(view: :new)
     |> assign(editing_plan: nil)
     |> assign_plan_form(Nutrition.change_diet_plan(%DietPlan{start_date: Date.utc_today()}))}
  end

  @impl true
  def handle_event("view_plan", %{"id" => id}, socket) do
    plan = Nutrition.get_diet_plan_with_meals!(id)

    {:noreply,
     socket
     |> assign(view: :detail)
     |> assign(selected_plan: plan)
     |> assign(adding_meal: false)}
  end

  @impl true
  def handle_event("edit_plan", %{"id" => id}, socket) do
    plan = Nutrition.get_diet_plan!(id)

    {:noreply,
     socket
     |> assign(view: :edit)
     |> assign(editing_plan: plan)
     |> assign_plan_form(Nutrition.change_diet_plan(plan))}
  end

  @impl true
  def handle_event("back_to_list", _params, socket) do
    {:noreply,
     socket
     |> assign(view: :list)
     |> assign(selected_plan: nil)
     |> assign(editing_plan: nil)
     |> assign(adding_meal: false)
     |> assign(diet_plans: Nutrition.list_diet_plans())}
  end

  # Plan CRUD
  @impl true
  def handle_event("validate_plan", %{"diet_plan" => params}, socket) do
    plan = socket.assigns.editing_plan || %DietPlan{}

    changeset =
      plan
      |> Nutrition.change_diet_plan(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_plan_form(socket, changeset)}
  end

  @impl true
  def handle_event("save_plan", %{"diet_plan" => params}, socket) do
    save_plan(socket, socket.assigns.editing_plan, params)
  end

  @impl true
  def handle_event("delete_plan", %{"id" => id}, socket) do
    plan = Nutrition.get_diet_plan!(id)
    {:ok, _} = Nutrition.delete_diet_plan(plan)

    {:noreply,
     socket
     |> assign(view: :list)
     |> assign(selected_plan: nil)
     |> assign(diet_plans: Nutrition.list_diet_plans())}
  end

  # Meal management
  @impl true
  def handle_event("show_add_meal", _params, socket) do
    {:noreply,
     socket
     |> assign(adding_meal: true)
     |> assign_meal_form(Nutrition.change_meal(%Meal{scheduled_date: socket.assigns.selected_date}))}
  end

  @impl true
  def handle_event("cancel_add_meal", _params, socket) do
    {:noreply, assign(socket, adding_meal: false)}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    date = Date.from_iso8601!(date_string)
    {:noreply, assign(socket, selected_date: date)}
  end

  @impl true
  def handle_event("validate_meal", %{"meal" => params}, socket) do
    changeset =
      %Meal{}
      |> Nutrition.change_meal(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_meal_form(socket, changeset)}
  end

  @impl true
  def handle_event("save_meal", %{"meal" => params}, socket) do
    params =
      params
      |> Map.put("diet_plan_id", socket.assigns.selected_plan.id)
      |> Map.put("scheduled_date", Date.to_iso8601(socket.assigns.selected_date))

    case Nutrition.create_meal(params) do
      {:ok, _meal} ->
        plan = Nutrition.get_diet_plan_with_meals!(socket.assigns.selected_plan.id)

        {:noreply,
         socket
         |> assign(selected_plan: plan)
         |> assign(adding_meal: false)
         |> assign_meal_form(Nutrition.change_meal(%Meal{}))}

      {:error, changeset} ->
        {:noreply, assign_meal_form(socket, changeset)}
    end
  end

  @impl true
  def handle_event("delete_meal", %{"id" => id}, socket) do
    meal = Nutrition.get_meal!(id)
    {:ok, _} = Nutrition.delete_meal(meal)

    plan = Nutrition.get_diet_plan_with_meals!(socket.assigns.selected_plan.id)
    {:noreply, assign(socket, selected_plan: plan)}
  end

  @impl true
  def handle_event("mark_taken", %{"id" => id}, socket) do
    meal = Nutrition.get_meal!(id)
    {:ok, _} = Nutrition.mark_meal_taken(meal)

    plan = Nutrition.get_diet_plan_with_meals!(socket.assigns.selected_plan.id)
    {:noreply, assign(socket, selected_plan: plan)}
  end

  @impl true
  def handle_event("mark_missed", %{"id" => id}, socket) do
    meal = Nutrition.get_meal!(id)
    {:ok, _} = Nutrition.mark_meal_missed(meal)

    plan = Nutrition.get_diet_plan_with_meals!(socket.assigns.selected_plan.id)
    {:noreply, assign(socket, selected_plan: plan)}
  end

  @impl true
  def handle_event("reset_status", %{"id" => id}, socket) do
    meal = Nutrition.get_meal!(id)
    {:ok, _} = Nutrition.reset_meal_status(meal)

    plan = Nutrition.get_diet_plan_with_meals!(socket.assigns.selected_plan.id)
    {:noreply, assign(socket, selected_plan: plan)}
  end

  defp save_plan(socket, nil, params) do
    # Auto-create meals for each day in the plan's date range
    case Nutrition.create_diet_plan_with_meals(params) do
      {:ok, plan} ->
        {:noreply,
         socket
         |> assign(view: :detail)
         |> assign(selected_plan: plan)
         |> assign(diet_plans: Nutrition.list_diet_plans())}

      {:error, changeset} ->
        {:noreply, assign_plan_form(socket, changeset)}
    end
  end

  defp save_plan(socket, plan, params) do
    case Nutrition.update_diet_plan(plan, params) do
      {:ok, updated_plan} ->
        plan = Nutrition.get_diet_plan_with_meals!(updated_plan.id)

        {:noreply,
         socket
         |> assign(view: :detail)
         |> assign(selected_plan: plan)
         |> assign(editing_plan: nil)
         |> assign(diet_plans: Nutrition.list_diet_plans())}

      {:error, changeset} ->
        {:noreply, assign_plan_form(socket, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= case @view do %>
        <% :list -> %>
          <.plan_list {assigns} />
        <% :new -> %>
          <.plan_form {assigns} title="Create New Plan" />
        <% :edit -> %>
          <.plan_form {assigns} title="Edit Plan" />
        <% :detail -> %>
          <.plan_detail {assigns} />
      <% end %>
    </div>
    """
  end

  defp plan_list(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <h2 class="text-2xl font-bold text-white">Diet Plans</h2>
      <button
        phx-click="new_plan"
        phx-target={@myself}
        class="cosmic-button px-4 py-2 rounded-lg font-medium flex items-center gap-2"
      >
        <.icon name="hero-plus" class="w-5 h-5" />
        New Plan
      </button>
    </div>

    <div :if={@diet_plans == []} class="cosmic-card p-12 rounded-2xl text-center">
      <.icon name="hero-clipboard-document-list" class="w-16 h-16 mx-auto text-purple-400 opacity-50 mb-4" />
      <h3 class="text-xl text-white mb-2">No Diet Plans Yet</h3>
      <p class="text-purple-300 mb-6">Create your first diet plan to start tracking your nutrition journey.</p>
      <button
        phx-click="new_plan"
        phx-target={@myself}
        class="cosmic-button px-6 py-3 rounded-lg font-medium"
      >
        Create Your First Plan
      </button>
    </div>

    <div :if={@diet_plans != []} class="grid gap-4">
      <button
        :for={plan <- @diet_plans}
        phx-click="view_plan"
        phx-target={@myself}
        phx-value-id={plan.id}
        class="cosmic-card p-6 rounded-2xl text-left hover:border-purple-400 transition-all cursor-pointer group"
      >
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-xl font-semibold text-white mb-1 group-hover:text-purple-300 transition-colors">
              {plan.name}
            </h3>
            <p :if={plan.description} class="text-purple-300 text-sm mb-3 line-clamp-2">
              {plan.description}
            </p>
            <div class="flex items-center gap-4 text-sm text-purple-400">
              <div class="flex items-center gap-2">
                <.icon name="hero-calendar" class="w-4 h-4" />
                <span>{format_date(plan.start_date)}</span>
              </div>
              <div :if={plan.end_date} class="flex items-center gap-2">
                <span>to {format_date(plan.end_date)}</span>
              </div>
            </div>
          </div>
          <.icon name="hero-chevron-right" class="w-6 h-6 text-purple-400 group-hover:text-purple-300 transition-colors" />
        </div>
      </button>
    </div>
    """
  end

  defp plan_form(assigns) do
    ~H"""
    <div>
      <button
        phx-click="back_to_list"
        phx-target={@myself}
        class="flex items-center gap-2 text-purple-300 hover:text-white mb-6 transition-colors"
      >
        <.icon name="hero-arrow-left" class="w-5 h-5" />
        Back to Plans
      </button>

      <div class="cosmic-card p-6 rounded-2xl">
        <h2 class="text-2xl font-bold text-white mb-6">{@title}</h2>

        <.form
          for={@plan_form}
          phx-target={@myself}
          phx-change="validate_plan"
          phx-submit="save_plan"
          class="space-y-4"
        >
          <div>
            <label class="block text-purple-200 text-sm mb-2">Plan Name *</label>
            <.input
              field={@plan_form[:name]}
              type="text"
              placeholder="e.g., Healthy Eating Plan"
              class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
            />
          </div>

          <div>
            <label class="block text-purple-200 text-sm mb-2">Description</label>
            <.input
              field={@plan_form[:description]}
              type="textarea"
              rows="2"
              placeholder="Brief description..."
              class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
            />
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-purple-200 text-sm mb-2">Start Date *</label>
              <.input
                field={@plan_form[:start_date]}
                type="date"
                class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
              />
            </div>
            <div>
              <label class="block text-purple-200 text-sm mb-2">End Date</label>
              <.input
                field={@plan_form[:end_date]}
                type="date"
                class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
              />
            </div>
          </div>

          <div class="flex gap-3 pt-4">
            <button type="submit" class="cosmic-button px-6 py-2 rounded-lg font-medium">
              {if @editing_plan, do: "Save Changes", else: "Create Plan"}
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

  defp plan_detail(assigns) do
    meals_by_date = assigns.selected_plan.meals |> Enum.group_by(& &1.scheduled_date)
    stats = Nutrition.get_meal_stats(assigns.selected_plan.id)
    assigns = assign(assigns, meals_by_date: meals_by_date, stats: stats)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <button
          phx-click="back_to_list"
          phx-target={@myself}
          class="flex items-center gap-2 text-purple-300 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="w-5 h-5" />
          Back to Plans
        </button>

        <div class="flex items-center gap-2">
          <button
            phx-click="edit_plan"
            phx-target={@myself}
            phx-value-id={@selected_plan.id}
            class="p-2 text-purple-300 hover:text-white hover:bg-purple-500/20 rounded-lg transition-colors"
          >
            <.icon name="hero-pencil" class="w-5 h-5" />
          </button>
          <button
            phx-click="delete_plan"
            phx-target={@myself}
            phx-value-id={@selected_plan.id}
            data-confirm="Delete this plan and all its meals?"
            class="p-2 text-red-400 hover:text-red-300 hover:bg-red-500/20 rounded-lg transition-colors"
          >
            <.icon name="hero-trash" class="w-5 h-5" />
          </button>
        </div>
      </div>

      <div class="cosmic-card p-6 rounded-2xl mb-6">
        <h2 class="text-2xl font-bold text-white mb-2">{@selected_plan.name}</h2>
        <p :if={@selected_plan.description} class="text-purple-300 mb-4">{@selected_plan.description}</p>

        <div class="flex items-center gap-6 text-sm text-purple-400 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-calendar" class="w-4 h-4" />
            <span>{format_date(@selected_plan.start_date)}</span>
            <span :if={@selected_plan.end_date}>to {format_date(@selected_plan.end_date)}</span>
          </div>
        </div>

        <div :if={@stats.total > 0} class="grid grid-cols-4 gap-4 pt-4 border-t border-purple-500/20">
          <div class="text-center">
            <p class="text-2xl font-bold text-white">{@stats.total}</p>
            <p class="text-purple-400 text-xs">Total</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-emerald-400">{@stats.taken}</p>
            <p class="text-purple-400 text-xs">Taken</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-red-400">{@stats.missed}</p>
            <p class="text-purple-400 text-xs">Missed</p>
          </div>
          <div class="text-center">
            <p class="text-2xl font-bold text-yellow-400">{@stats.pending}</p>
            <p class="text-purple-400 text-xs">Pending</p>
          </div>
        </div>
      </div>

      <div class="cosmic-card p-6 rounded-2xl">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-white">Meals</h3>

          <div class="flex items-center gap-3">
            <input
              type="date"
              value={Date.to_iso8601(@selected_date)}
              phx-change="select_date"
              phx-target={@myself}
              name="date"
              class="px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
            />

            <button
              :if={!@adding_meal}
              phx-click="show_add_meal"
              phx-target={@myself}
              class="cosmic-button px-4 py-2 rounded-lg text-sm font-medium flex items-center gap-2"
            >
              <.icon name="hero-plus" class="w-4 h-4" />
              Add Meal
            </button>
          </div>
        </div>

        <div :if={@adding_meal} class="mb-6 p-4 rounded-xl bg-purple-900/20 border border-purple-500/20">
          <h4 class="text-white font-medium mb-4">
            Add meal for {Calendar.strftime(@selected_date, "%B %d, %Y")}
          </h4>

          <.form
            for={@meal_form}
            phx-target={@myself}
            phx-change="validate_meal"
            phx-submit="save_meal"
            class="space-y-4"
          >
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-purple-200 text-sm mb-2">Meal Name *</label>
                <.input
                  field={@meal_form[:name]}
                  type="text"
                  placeholder="e.g., Oatmeal with berries"
                  class="w-full px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
                />
              </div>
              <div>
                <label class="block text-purple-200 text-sm mb-2">Type *</label>
                <.input
                  field={@meal_form[:meal_type]}
                  type="select"
                  options={meal_type_options()}
                  class="w-full px-3 py-2 text-sm bg-purple-900/30 border border-purple-500/30 rounded-lg text-white focus:outline-none focus:border-purple-400"
                />
              </div>
            </div>

            <div class="flex gap-2">
              <button type="submit" class="px-4 py-2 text-sm rounded-lg bg-purple-500 text-white hover:bg-purple-600 transition-colors">
                Add Meal
              </button>
              <button
                type="button"
                phx-click="cancel_add_meal"
                phx-target={@myself}
                class="px-4 py-2 text-sm rounded-lg text-purple-300 hover:text-white border border-purple-500/30 hover:border-purple-400 transition-colors"
              >
                Cancel
              </button>
            </div>
          </.form>
        </div>

        <div :if={@selected_plan.meals == []} class="text-center py-8 text-purple-300">
          <.icon name="hero-cake" class="w-12 h-12 mx-auto opacity-50 mb-2" />
          <p>No meals added yet</p>
          <p class="text-sm text-purple-400">Select a date and add your first meal</p>
        </div>

        <div :if={@selected_plan.meals != []} class="space-y-6">
          <%= for {date, meals} <- @meals_by_date |> Enum.sort_by(fn {d, _} -> d end, Date) do %>
            <div>
              <h4 class="text-sm font-medium text-purple-400 mb-3">
                {Calendar.strftime(date, "%A, %B %d, %Y")}
              </h4>
              <div class="space-y-2">
                <div
                  :for={meal <- Enum.sort_by(meals, &meal_type_order(&1.meal_type))}
                  class={"flex items-center justify-between p-3 rounded-lg #{meal_bg(meal.status)}"}
                >
                  <div class="flex items-center gap-3">
                    <span class="text-lg">{meal_emoji(meal.meal_type)}</span>
                    <div>
                      <p class="text-white font-medium">{meal.name}</p>
                      <p class="text-purple-400 text-xs">{Meal.meal_type_display(meal.meal_type)}</p>
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <span class={"px-2 py-1 rounded text-xs font-medium #{status_badge(meal.status)}"}>
                      {meal.status |> String.capitalize()}
                    </span>

                    <button
                      :if={meal.status != "taken"}
                      phx-click="mark_taken"
                      phx-target={@myself}
                      phx-value-id={meal.id}
                      class="p-1.5 text-emerald-400 hover:bg-emerald-500/20 rounded transition-colors"
                      title="Mark taken"
                    >
                      <.icon name="hero-check" class="w-4 h-4" />
                    </button>
                    <button
                      :if={meal.status != "missed"}
                      phx-click="mark_missed"
                      phx-target={@myself}
                      phx-value-id={meal.id}
                      class="p-1.5 text-red-400 hover:bg-red-500/20 rounded transition-colors"
                      title="Mark missed"
                    >
                      <.icon name="hero-x-mark" class="w-4 h-4" />
                    </button>
                    <button
                      :if={meal.status != "pending"}
                      phx-click="reset_status"
                      phx-target={@myself}
                      phx-value-id={meal.id}
                      class="p-1.5 text-yellow-400 hover:bg-yellow-500/20 rounded transition-colors"
                      title="Reset"
                    >
                      <.icon name="hero-arrow-path" class="w-4 h-4" />
                    </button>
                    <button
                      phx-click="delete_meal"
                      phx-target={@myself}
                      phx-value-id={meal.id}
                      data-confirm="Delete this meal?"
                      class="p-1.5 text-red-400 hover:bg-red-500/20 rounded transition-colors"
                      title="Delete"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp meal_type_options do
    [
      {"Select type", ""},
      {"Pre-Breakfast", "pre_breakfast"},
      {"Breakfast", "breakfast"},
      {"Post-Breakfast", "post_breakfast"},
      {"Lunch", "lunch"},
      {"Evening Snack", "evening_snack"},
      {"Dinner", "dinner"}
    ]
  end

  defp meal_type_order("pre_breakfast"), do: 1
  defp meal_type_order("breakfast"), do: 2
  defp meal_type_order("post_breakfast"), do: 3
  defp meal_type_order("lunch"), do: 4
  defp meal_type_order("evening_snack"), do: 5
  defp meal_type_order("dinner"), do: 6
  defp meal_type_order(_), do: 7

  defp meal_emoji("pre_breakfast"), do: "dawn"
  defp meal_emoji("breakfast"), do: "sunrise"
  defp meal_emoji("post_breakfast"), do: "morning"
  defp meal_emoji("lunch"), do: "sun"
  defp meal_emoji("evening_snack"), do: "sunset"
  defp meal_emoji("dinner"), do: "moon"
  defp meal_emoji(_), do: "plate"

  defp meal_bg("taken"), do: "bg-emerald-900/20 border border-emerald-500/20"
  defp meal_bg("missed"), do: "bg-red-900/20 border border-red-500/20"
  defp meal_bg(_), do: "bg-purple-900/30 border border-purple-500/20"

  defp status_badge("taken"), do: "bg-emerald-500/20 text-emerald-300"
  defp status_badge("missed"), do: "bg-red-500/20 text-red-300"
  defp status_badge(_), do: "bg-yellow-500/20 text-yellow-300"

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
end
