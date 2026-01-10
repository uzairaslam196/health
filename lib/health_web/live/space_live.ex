defmodule HealthWeb.SpaceLive do
  use HealthWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    # Read role from session (set by SpaceAuthController)
    role_string = Map.get(session, "space_role")
    role = parse_role(role_string)

    socket =
      socket
      |> assign(page_title: "Personal Space")
      |> assign(role: role)
      |> assign(authenticated: role != nil)
      |> assign(email: "")
      |> assign(password: "")
      |> assign(active_tab: :dashboard)

    {:ok, socket}
  end

  defp parse_role("nutritionist"), do: :nutritionist
  defp parse_role("seeker"), do: :seeker
  defp parse_role(_), do: nil

  @impl true
  def handle_params(params, _uri, socket) do
    # Only handle params if authenticated
    if socket.assigns.authenticated do
      tab = case params["tab"] do
        "meals" -> :meals
        "messages" -> :messages
        "plans" -> :plans
        _ -> :dashboard
      end

      {:noreply, assign(socket, active_tab: tab)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_login", params, socket) do
    {:noreply,
     socket
     |> assign(email: params["email"] || "")
     |> assign(password: params["password"] || "")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen cosmic-bg">
      <div class="stars"></div>
      <div class="twinkling"></div>

      <%= if @authenticated do %>
        <.authenticated_view {assigns} />
      <% else %>
        <.pin_entry_view {assigns} />
      <% end %>
    </div>
    """
  end

  defp pin_entry_view(assigns) do
    ~H"""
    <div class="relative z-10 flex flex-col items-center justify-center min-h-screen px-4">
      <div class="cosmic-card p-8 rounded-2xl backdrop-blur-lg max-w-md w-full">
        <div class="text-center mb-8">
          <div class="text-4xl mb-4">
            <span class="cosmic-glow">*</span>
          </div>
          <h2 class="text-2xl font-bold text-white mb-2">Enter Personal Space</h2>
          <p class="text-purple-200 text-sm">Sign in to access your wellness journey</p>
        </div>

        <form action={~p"/space/login"} method="post" phx-change="validate_login" class="space-y-6">
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
          <div>
            <label class="block text-purple-200 text-sm mb-2">Email</label>
            <input
              type="email"
              name="email"
              value={@email}
              placeholder="Enter your email"
              autocomplete="email"
              class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400 focus:ring-1 focus:ring-purple-400"
            />
          </div>

          <div>
            <label class="block text-purple-200 text-sm mb-2">Password</label>
            <input
              type="password"
              name="password"
              value={@password}
              placeholder="Enter your password"
              autocomplete="current-password"
              class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400 focus:ring-1 focus:ring-purple-400"
            />
          </div>

          <button
            type="submit"
            class="w-full cosmic-button py-3 rounded-lg font-semibold transition-all duration-300 hover:scale-[1.02]"
          >
            Enter Space
          </button>
        </form>

        <div class="mt-6 text-center">
          <.link navigate={~p"/"} class="text-purple-300 hover:text-purple-100 text-sm">
            Back to Home
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp authenticated_view(assigns) do
    ~H"""
    <div class="relative z-10 min-h-screen">
      <nav class="cosmic-nav backdrop-blur-lg border-b border-purple-500/20">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <div class="flex items-center gap-4">
              <span class="cosmic-glow text-2xl">*</span>
              <span class="text-white font-semibold">Personal Space</span>
              <span class={"px-3 py-1 rounded-full text-xs font-medium #{role_badge_class(@role)}"}>
                {role_display(@role)}
              </span>
            </div>

            <div class="flex items-center gap-4">
              <.link
                patch={~p"/space"}
                class={"nav-link #{if @active_tab == :dashboard, do: "active"}"}
              >
                <.icon name="hero-home" class="w-5 h-5" />
                <span class="hidden sm:inline">Dashboard</span>
              </.link>

              <.link
                patch={~p"/space?tab=meals"}
                class={"nav-link #{if @active_tab == :meals, do: "active"}"}
              >
                <.icon name="hero-calendar-days" class="w-5 h-5" />
                <span class="hidden sm:inline">Routine</span>
              </.link>

              <.link
                patch={~p"/space?tab=plans"}
                class={"nav-link #{if @active_tab == :plans, do: "active"}"}
              >
                <.icon name="hero-sparkles" class="w-5 h-5" />
                <span class="hidden sm:inline">Orbits</span>
              </.link>

              <.link
                patch={~p"/space?tab=messages"}
                class={"nav-link #{if @active_tab == :messages, do: "active"}"}
              >
                <.icon name="hero-chat-bubble-left-right" class="w-5 h-5" />
                <span class="hidden sm:inline">Messages</span>
              </.link>

              <.link
                href={~p"/space/logout"}
                class="text-purple-300 hover:text-white transition-colors ml-4"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
              </.link>
            </div>
          </div>
        </div>
      </nav>

      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= case @active_tab do %>
          <% :dashboard -> %>
            <.live_component module={HealthWeb.DashboardComponent} id="dashboard" role={@role} />
          <% :plans -> %>
            <.live_component module={HealthWeb.OrbitsComponent} id="orbits" role={@role} />
          <% :meals -> %>
            <.live_component module={HealthWeb.MealsComponent} id="meals" role={@role} />
          <% :messages -> %>
            <.live_component module={HealthWeb.MessagesComponent} id="messages" role={@role} />
        <% end %>
      </main>
    </div>
    """
  end

  defp role_display(:nutritionist), do: "Nutritionist"
  defp role_display(:seeker), do: "Health Seeker"

  defp role_badge_class(:nutritionist), do: "bg-emerald-500/20 text-emerald-300 border border-emerald-500/30"
  defp role_badge_class(:seeker), do: "bg-blue-500/20 text-blue-300 border border-blue-500/30"
end
