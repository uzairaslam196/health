defmodule HealthWeb.RoastLive do
  use HealthWeb, :live_view

  alias Health.Roast.RoomState

  @weapons %{
    "chappal" => %{name: "Chappal", damage: 2, chance_mod: 0, icon: "🩴"},
    "belt" => %{name: "Belt", damage: 3, chance_mod: -10, icon: "🥋"},
    "hanger" => %{name: "Hanger", damage: 4, chance_mod: -20, icon: "🪝"},
    "belan" => %{name: "Belan", damage: 5, chance_mod: -30, icon: "🪵"}
  }

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Health.PubSub, "roast:#{room_id}")
      # Start timer tick if game is in progress
      room = RoomState.get_or_create_room(room_id)
      if room.phase == :playing do
        Process.send_after(self(), :tick, 1000)
      end
    end

    room = RoomState.get_or_create_room(room_id)
    player_id = generate_player_id()

    socket =
      socket
      |> assign(page_title: "Chappal Chase - #{room_id}")
      |> assign(room_id: room_id)
      |> assign(player_id: player_id)
      |> assign(username: nil)
      |> assign(username_input: "")
      |> assign(room: room)
      |> assign(selected_weapon: "chappal")
      |> assign(last_hit_result: nil)
      |> assign(roast_text: nil)
      |> assign(weapons: @weapons)

    {:ok, socket}
  end

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  @impl true
  def handle_event("update_username", %{"username" => username}, socket) do
    {:noreply, assign(socket, username_input: username)}
  end

  @impl true
  def handle_event("join", %{"username" => username}, socket) do
    username = String.trim(username)
    if username != "" do
      participant = %{
        id: socket.assigns.player_id,
        username: username,
        avatar: nil,
        score: 0,
        hits: 0,
        misses: 0
      }

      RoomState.add_participant(socket.assigns.room_id, participant)
      room = RoomState.get_room(socket.assigns.room_id)

      broadcast(socket.assigns.room_id, {:player_joined, participant})

      socket =
        socket
        |> assign(username: username, room: room)
        |> push_event("persist_session", %{
          player_id: socket.assigns.player_id,
          username: username
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("restore_session", params, socket) do
    username = params |> Map.get("username", "") |> to_string() |> String.trim()
    player_id = params |> Map.get("player_id", "") |> to_string() |> String.trim()

    if username == "" or player_id == "" do
      {:noreply, socket}
    else
      room = RoomState.get_room(socket.assigns.room_id)
      existing = room && Enum.find(room.participants, &(&1.id == player_id))

      {room, resolved_username, added?} =
        if existing do
          {room, existing.username, false}
        else
          participant = %{
            id: player_id,
            username: username,
            avatar: nil,
            score: 0,
            hits: 0,
            misses: 0
          }

          RoomState.add_participant(socket.assigns.room_id, participant)
          {RoomState.get_room(socket.assigns.room_id), username, true}
        end

      if added? do
        broadcast(socket.assigns.room_id, {:player_joined, %{id: player_id, username: resolved_username}})
      end

      {:noreply,
       socket
       |> assign(player_id: player_id)
       |> assign(username: resolved_username)
       |> assign(username_input: resolved_username)
       |> assign(room: room)}
    end
  end

  @impl true
  def handle_event("select_victim", %{"username" => victim_username}, socket) do
    victim = %{username: victim_username, face_url: nil}
    RoomState.set_victim(socket.assigns.room_id, victim)
    room = RoomState.get_room(socket.assigns.room_id)

    broadcast(socket.assigns.room_id, {:victim_selected, victim})

    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    RoomState.start_game(socket.assigns.room_id)
    room = RoomState.get_room(socket.assigns.room_id)

    broadcast(socket.assigns.room_id, :game_started)
    Process.send_after(self(), :tick, 1000)

    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_event("select_weapon", %{"weapon" => weapon}, socket) do
    {:noreply, assign(socket, selected_weapon: weapon)}
  end

  @impl true
  def handle_event("hit_attempt", params, socket) do
    if socket.assigns.room.phase == :playing and socket.assigns.username do
      weapon = @weapons[socket.assigns.selected_weapon]

      # If bullet hit directly (forced_hit from JS), always count as hit
      # Otherwise use RNG for manual clicks
      forced_hit = Map.get(params, "forced_hit", false)

      is_hit = if forced_hit do
        true
      else
        base_chance = 60
        hit_chance = base_chance + weapon.chance_mod
        :rand.uniform(100) <= hit_chance
      end

      if is_hit do
        # HIT!
        RoomState.record_hit(socket.assigns.room_id, socket.assigns.player_id, weapon.damage)
        room = RoomState.get_room(socket.assigns.room_id)

        broadcast(socket.assigns.room_id, {:hit, %{
          player_id: socket.assigns.player_id,
          username: socket.assigns.username,
          weapon: socket.assigns.selected_weapon,
          damage: weapon.damage
        }})

        # Check for game over
        if room.phase == :roast do
          winner = RoomState.get_winner(socket.assigns.room_id)
          roast = generate_roast(room.victim, winner, room)
          broadcast(socket.assigns.room_id, {:game_over, winner, roast})
          {:noreply, assign(socket, room: room, last_hit_result: :hit, roast_text: roast)}
        else
          {:noreply, assign(socket, room: room, last_hit_result: :hit)}
        end
      else
        # MISS!
        RoomState.record_miss(socket.assigns.room_id, socket.assigns.player_id)
        room = RoomState.get_room(socket.assigns.room_id)

        broadcast(socket.assigns.room_id, {:miss, %{
          player_id: socket.assigns.player_id,
          username: socket.assigns.username
        }})

        {:noreply, assign(socket, room: room, last_hit_result: :miss)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("play_again", _params, socket) do
    RoomState.reset_game(socket.assigns.room_id)
    room = RoomState.get_room(socket.assigns.room_id)

    broadcast(socket.assigns.room_id, :game_reset)

    {:noreply, assign(socket, room: room, roast_text: nil, last_hit_result: nil)}
  end

  @impl true
  def handle_event("share_whatsapp", _params, socket) do
    # WhatsApp sharing is handled client-side via the link
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    if socket.assigns.room.phase == :playing do
      RoomState.tick_timer(socket.assigns.room_id)
      room = RoomState.get_room(socket.assigns.room_id)

      if room.phase == :roast do
        # Timer ran out - game over
        winner = RoomState.get_winner(socket.assigns.room_id)
        roast = generate_roast(room.victim, winner, room)
        broadcast(socket.assigns.room_id, {:game_over, winner, roast})
        {:noreply, assign(socket, room: room, roast_text: roast)}
      else
        broadcast(socket.assigns.room_id, {:timer_tick, room.timer_seconds})
        Process.send_after(self(), :tick, 1000)
        {:noreply, assign(socket, room: room)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:player_joined, _participant}, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info({:victim_selected, _victim}, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info(:game_started, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    if room.phase == :playing do
      Process.send_after(self(), :tick, 1000)
    end
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info({:hit, data}, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    # Push event to JS hook to show blood effect
    socket = push_event(socket, "hit", data)
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info({:miss, data}, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    socket = push_event(socket, "miss", data)
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info({:timer_tick, _seconds}, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    {:noreply, assign(socket, room: room)}
  end

  @impl true
  def handle_info({:game_over, _winner, roast}, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    {:noreply, assign(socket, room: room, roast_text: roast)}
  end

  @impl true
  def handle_info(:game_reset, socket) do
    room = RoomState.get_room(socket.assigns.room_id)
    {:noreply, assign(socket, room: room, roast_text: nil, last_hit_result: nil)}
  end

  defp broadcast(room_id, message) do
    Phoenix.PubSub.broadcast(Health.PubSub, "roast:#{room_id}", message)
  end

  defp generate_roast(victim, winner, room) do
    victim_name = if victim, do: victim.username, else: "The Victim"
    winner_name = if winner, do: winner.username, else: "Someone"
    total_hits = room.hit_count

    templates = [
      "#{victim_name}'s butt got DESTROYED! #{winner_name} landed the most hits. That butt will never be the same! 🍑💀",
      "RIP #{victim_name}'s dignity! #{winner_name} showed no mercy with #{total_hits} total hits on that poor butt!",
      "#{victim_name} won't be sitting down for a WEEK! #{winner_name} is the Chappal Champion! 🏆🩴",
      "Blood everywhere! #{victim_name}'s butt looks like a crime scene! #{winner_name} is a certified MENACE!",
      "#{winner_name} beat that butt like it owed them money! #{victim_name} should start running NOW! 🏃💨",
      "That wasn't a game, that was an ASSASSINATION! #{victim_name} is officially roasted! 🔥🍑🔥",
      "#{total_hits} hits?! #{victim_name}'s butt is now a historical landmark of destruction! All thanks to #{winner_name}!"
    ]

    Enum.random(templates)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="roast-root"
      class="min-h-screen cosmic-bg"
      phx-hook="RoastSession"
      data-room-id={@room_id}
    >
      <div class="stars"></div>
      <div class="twinkling"></div>

      <div class="relative z-10">
        <!-- Header -->
        <header class="cosmic-nav backdrop-blur-lg border-b border-purple-500/20 px-4 py-3">
          <div class="max-w-4xl mx-auto flex items-center justify-between">
            <div class="flex items-center gap-3">
              <span class="text-2xl">🩴</span>
              <div>
                <h1 class="text-white font-bold text-lg">Chappal Chase</h1>
                <p class="text-purple-300 text-xs">Room: {@room_id}</p>
              </div>
            </div>
            <div class="flex items-center gap-2 text-purple-300">
              <.icon name="hero-users" class="w-5 h-5" />
              <span>{length(@room.participants)}</span>
            </div>
          </div>
        </header>

        <main class="max-w-4xl mx-auto px-4 py-4">
          <%= case @room.phase do %>
            <% :lobby -> %>
              <.lobby_view
                room={@room}
                username={@username}
                username_input={@username_input}
                player_id={@player_id}
              />
            <% :playing -> %>
              <.game_view
                room={@room}
                username={@username}
                selected_weapon={@selected_weapon}
                weapons={@weapons}
                last_hit_result={@last_hit_result}
              />
            <% :roast -> %>
              <.roast_view
                room={@room}
                roast_text={@roast_text}
                room_id={@room_id}
              />
          <% end %>
        </main>
      </div>
    </div>
    """
  end

  defp lobby_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <%= if @username == nil do %>
        <!-- Join Form -->
        <div class="cosmic-card p-6 rounded-2xl">
          <h2 class="text-xl font-bold text-white mb-4 text-center">Join the Roast!</h2>
          <form phx-submit="join" phx-change="update_username" class="space-y-4">
            <div>
              <label class="block text-purple-200 text-sm mb-2">Your Name</label>
              <input
                type="text"
                name="username"
                value={@username_input}
                placeholder="Enter your name..."
                autocomplete="off"
                class="w-full px-4 py-3 bg-purple-900/30 border border-purple-500/30 rounded-lg text-white placeholder-purple-300/50 focus:outline-none focus:border-purple-400"
              />
            </div>
            <button
              type="submit"
              class="w-full cosmic-button py-3 rounded-lg font-semibold"
            >
              Join Room 🔥
            </button>
          </form>
        </div>
      <% else %>
        <!-- Participants -->
        <div class="cosmic-card p-6 rounded-2xl">
          <h2 class="text-xl font-bold text-white mb-4">Players in Room</h2>
          <div class="space-y-2">
            <%= for p <- @room.participants do %>
              <div class="flex items-center justify-between p-3 rounded-lg bg-purple-900/30">
                <div class="flex items-center gap-3">
                  <span class="text-2xl">😈</span>
                  <span class="text-white font-medium">{p.username}</span>
                  <%= if p.id == @player_id do %>
                    <span class="text-xs text-purple-400">(you)</span>
                  <% end %>
                </div>
                <%= if @room.victim == nil do %>
                  <button
                    phx-click="select_victim"
                    phx-value-username={p.username}
                    class="px-3 py-1 text-sm rounded-lg bg-red-500/20 text-red-300 hover:bg-red-500/30"
                  >
                    Target 🎯
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Victim Selected -->
        <%= if @room.victim do %>
          <div class="cosmic-card p-6 rounded-2xl border-2 border-red-500/50">
            <div class="text-center">
              <p class="text-red-400 text-sm mb-2">TODAY'S VICTIM</p>
              <p class="text-3xl font-bold text-white mb-4">{@room.victim.username} 🍑</p>
              <button
                phx-click="start_game"
                class="cosmic-button px-8 py-4 rounded-lg text-lg font-bold"
              >
                START THE CARNAGE! 🩴💥
              </button>
            </div>
          </div>
        <% end %>

        <!-- Share Link -->
        <div class="cosmic-card p-4 rounded-2xl">
          <p class="text-purple-300 text-sm text-center mb-2">Share this room:</p>
          <div class="flex items-center gap-2">
            <input
              type="text"
              readonly
              value={"#{HealthWeb.Endpoint.url()}/roast/#{@room.room_id}"}
              class="flex-1 px-3 py-2 bg-purple-900/30 border border-purple-500/30 rounded-lg text-purple-200 text-sm"
            />
            <a
              href={"https://wa.me/?text=Join%20my%20Chappal%20Chase%20room!%20#{URI.encode(HealthWeb.Endpoint.url())}/roast/#{@room.room_id}"}
              target="_blank"
              class="px-4 py-2 bg-green-600 hover:bg-green-700 rounded-lg text-white text-sm font-medium"
            >
              WhatsApp
            </a>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp game_view(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Timer & Health -->
      <div class="flex items-center justify-between gap-4">
        <div class="cosmic-card px-4 py-2 rounded-xl flex items-center gap-2">
          <span class="text-2xl">⏱️</span>
          <span class="text-2xl font-bold text-white">{@room.timer_seconds}s</span>
        </div>
        <div class="cosmic-card px-4 py-2 rounded-xl flex-1">
          <div class="flex items-center gap-2">
            <span class="text-sm text-purple-300">Butt HP:</span>
            <div class="flex-1 h-4 bg-purple-900/50 rounded-full overflow-hidden">
              <div
                class="h-full bg-gradient-to-r from-red-500 to-red-600 transition-all duration-300"
                style={"width: #{@room.butt_health}%"}
              />
            </div>
            <span class="text-white font-bold">{@room.butt_health}</span>
          </div>
        </div>
      </div>

      <!-- Game Arena -->
      <div
        id="hip-arena"
        class="hip-arena cosmic-card rounded-2xl"
        phx-hook="HipMover"
        data-damage-level={@room.damage_level}
      >
        <div class="butt-character" id="butt-character">
          <!-- Arms -->
          <div class="arm left"><div class="hand"></div></div>
          <div class="arm right"><div class="hand"></div></div>

          <!-- The Big Butt -->
          <div class="butt" id="the-butt" data-damage={@room.damage_level}>
            <div class="butt-cheek left"></div>
            <div class="butt-cheek right"></div>
            <div class="butt-crack"></div>
            <div class="butt-hole"></div>
            <!-- Victim face - uses uploaded image -->
            <div class="victim-face-container">
              <img src="/images/victim-face.jpeg" alt="Victim" class="victim-face-img" />
            </div>
            <!-- Blood container -->
            <div class="blood-container" id="blood-container"></div>
            <div class="blood-pool"></div>
          </div>

          <!-- Pants & Legs -->
          <div class="pants"></div>
          <div class="legs">
            <div class="leg"><div class="shoe"></div></div>
            <div class="leg"><div class="shoe"></div></div>
          </div>
        </div>
      </div>

      <!-- Leaderboard -->
      <div class="cosmic-card p-4 rounded-xl">
        <div class="flex items-center justify-around">
          <%= for {p, idx} <- @room.participants |> Enum.sort_by(&(-(&1.score || 0))) |> Enum.with_index() do %>
            <div class="text-center">
              <span class="text-lg">{["🥇", "🥈", "🥉", "4️⃣", "5️⃣"] |> Enum.at(idx, "👤")}</span>
              <p class="text-white font-medium text-sm truncate max-w-[80px]">{p.username}</p>
              <p class="text-purple-300 text-xs">{p.score || 0} pts</p>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Weapon Selector -->
      <div class="weapon-bar">
        <%= for {key, weapon} <- @weapons do %>
          <button
            phx-click="select_weapon"
            phx-value-weapon={key}
            class={"weapon-item #{if @selected_weapon == key, do: "selected"}"}
          >
            <span>{weapon.icon}</span>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp roast_view(assigns) do
    winner = RoomState.get_winner(assigns.room.room_id)
    assigns = assign(assigns, :winner, winner)

    ~H"""
    <div class="space-y-6">
      <!-- Winner Announcement -->
      <div class="cosmic-card p-8 rounded-2xl text-center">
        <p class="text-purple-400 text-sm mb-2">👑 CHAPPAL CHAMPION 👑</p>
        <h2 class="text-4xl font-bold text-white mb-4">{if @winner, do: @winner.username, else: "Nobody"}</h2>
        <p class="text-2xl text-purple-200">{if @winner, do: "#{@winner.score || 0} points!", else: ""}</p>
      </div>

      <!-- The Roast -->
      <div class="cosmic-card p-6 rounded-2xl border-2 border-red-500/50">
        <div class="text-center">
          <p class="text-red-400 text-sm mb-4">🔥 THE ROAST 🔥</p>
          <p class="text-xl text-white leading-relaxed">{@roast_text}</p>
        </div>
      </div>

      <!-- Final Stats -->
      <div class="cosmic-card p-6 rounded-2xl">
        <h3 class="text-lg font-bold text-white mb-4 text-center">Final Scores</h3>
        <div class="space-y-2">
          <%= for {p, idx} <- @room.participants |> Enum.sort_by(&(-(&1.score || 0))) |> Enum.with_index() do %>
            <div class="flex items-center justify-between p-3 rounded-lg bg-purple-900/30">
              <div class="flex items-center gap-3">
                <span class="text-xl">{["🥇", "🥈", "🥉"] |> Enum.at(idx, "#{idx + 1}.")}</span>
                <span class="text-white">{p.username}</span>
              </div>
              <div class="text-right">
                <p class="text-white font-bold">{p.score || 0} pts</p>
                <p class="text-purple-400 text-xs">{p.hits || 0} hits / {p.misses || 0} misses</p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex gap-4">
        <button
          phx-click="play_again"
          class="flex-1 cosmic-button py-4 rounded-lg font-bold text-lg"
        >
          Play Again! 🔄
        </button>
        <a
          href={"https://wa.me/?text=#{URI.encode(@roast_text || "Check out Chappal Chase!")}"}
          target="_blank"
          class="px-6 py-4 bg-green-600 hover:bg-green-700 rounded-lg text-white font-bold text-lg flex items-center gap-2"
        >
          <span>Share</span>
          <span>📱</span>
        </a>
      </div>
    </div>
    """
  end
end
