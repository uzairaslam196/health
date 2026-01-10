defmodule HealthWeb.HomeLive do
  use HealthWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Personal Health Tracker")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen cosmic-bg">
      <div class="stars"></div>
      <div class="twinkling"></div>

      <div class="relative z-10 flex flex-col items-center justify-center min-h-screen px-4 py-12">
        <div class="text-center max-w-4xl mx-auto">
          <div class="mb-8 animate-float">
            <div class="text-6xl mb-4">
              <span class="cosmic-glow">*</span>
            </div>
          </div>

          <h1 class="text-4xl md:text-6xl font-bold text-white mb-6 cosmic-title">
            Personal Health Tracker
          </h1>

          <p class="text-xl md:text-2xl text-purple-200 mb-12 max-w-2xl mx-auto leading-relaxed">
            This is a personal health tracker combined with a nutritionist support space.
          </p>

          <div class="grid md:grid-cols-3 gap-6 mb-12">
            <.feature_card
              icon="hero-heart"
              title="Health Tracking"
              description="Monitor your daily wellness journey with intuitive tracking tools designed for clarity and peace of mind."
            />

            <.feature_card
              icon="hero-clipboard-document-list"
              title="Diet Planning"
              description="Create personalized meal plans that align with your health goals and lifestyle preferences."
            />

            <.feature_card
              icon="hero-sparkles"
              title="Nutrition Guidance"
              description="Receive supportive guidance from your nutritionist through our calm, connected space."
            />
          </div>

          <.link
            navigate={~p"/space"}
            class="cosmic-button inline-flex items-center gap-3 px-8 py-4 text-lg font-semibold rounded-full transition-all duration-300 hover:scale-105"
          >
            <.icon name="hero-rocket-launch" class="w-6 h-6" />
            Enter Personal Space
          </.link>
        </div>

        <div class="absolute bottom-8 text-center">
          <p class="text-purple-300 text-sm opacity-75">
            Find your balance in the cosmos
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp feature_card(assigns) do
    ~H"""
    <div class="cosmic-card p-6 rounded-2xl backdrop-blur-lg">
      <div class="text-purple-400 mb-4">
        <.icon name={@icon} class="w-10 h-10 mx-auto" />
      </div>
      <h3 class="text-xl font-semibold text-white mb-3">{@title}</h3>
      <p class="text-purple-200 text-sm leading-relaxed">{@description}</p>
    </div>
    """
  end
end
