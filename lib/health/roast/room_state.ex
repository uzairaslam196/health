defmodule Health.Roast.RoomState do
  @moduledoc """
  ETS-backed room state management for Chappal Chase Carnage.
  All game state is stored in-memory - no database required.
  """

  @table :roast_rooms
  @default_timer_seconds 90

  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, read_concurrency: true])
    end
    :ok
  end

  def create_room(room_id) do
    init()
    room = %{
      room_id: room_id,
      participants: [],
      victim: nil,
      phase: :lobby,
      butt_health: 100,
      timer_seconds: @default_timer_seconds,
      damage_level: 0,
      hit_count: 0,
      messages: [],
      created_at: DateTime.utc_now()
    }
    :ets.insert(@table, {room_id, room})
    room
  end

  def get_room(room_id) do
    init()
    case :ets.lookup(@table, room_id) do
      [{^room_id, room}] -> room
      [] -> nil
    end
  end

  def get_or_create_room(room_id) do
    case get_room(room_id) do
      nil -> create_room(room_id)
      room -> room
    end
  end

  def update_room(room_id, updates) when is_map(updates) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        updated = Map.merge(room, updates)
        :ets.insert(@table, {room_id, updated})
        {:ok, updated}
    end
  end

  def add_participant(room_id, participant) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        # Check if already joined
        unless Enum.any?(room.participants, &(&1.id == participant.id)) do
          participants = room.participants ++ [participant]
          update_room(room_id, %{participants: participants})
        else
          {:ok, room}
        end
    end
  end

  def remove_participant(room_id, participant_id) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        participants = Enum.reject(room.participants, &(&1.id == participant_id))
        update_room(room_id, %{participants: participants})
    end
  end

  def set_victim(room_id, victim) do
    update_room(room_id, %{victim: victim})
  end

  def start_game(room_id) do
    update_room(room_id, %{
      phase: :playing,
      timer_seconds: @default_timer_seconds,
      butt_health: 100,
      damage_level: 0,
      hit_count: 0
    })
  end

  def record_hit(room_id, participant_id, damage) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        # Update participant score
        participants = Enum.map(room.participants, fn p ->
          if p.id == participant_id do
            %{p | score: (p.score || 0) + damage, hits: (p.hits || 0) + 1}
          else
            p
          end
        end)

        # Update butt health and damage level
        new_health = max(0, room.butt_health - damage)
        new_hit_count = room.hit_count + 1
        new_damage_level = min(5, div(new_hit_count, 3))

        updates = %{
          participants: participants,
          butt_health: new_health,
          hit_count: new_hit_count,
          damage_level: new_damage_level
        }

        # Check if game over
        updates = if new_health <= 0 do
          Map.put(updates, :phase, :roast)
        else
          updates
        end

        update_room(room_id, updates)
    end
  end

  def record_miss(room_id, participant_id) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        participants = Enum.map(room.participants, fn p ->
          if p.id == participant_id do
            %{p | misses: (p.misses || 0) + 1}
          else
            p
          end
        end)
        update_room(room_id, %{participants: participants})
    end
  end

  def tick_timer(room_id) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      %{phase: :playing, timer_seconds: seconds} when seconds > 0 ->
        update_room(room_id, %{timer_seconds: seconds - 1})
      %{phase: :playing, timer_seconds: 0} ->
        update_room(room_id, %{phase: :roast})
      room ->
        {:ok, room}
    end
  end

  def add_message(room_id, message) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        messages = (room.messages ++ [message]) |> Enum.take(-50)
        update_room(room_id, %{messages: messages})
    end
  end

  def get_winner(room_id) do
    case get_room(room_id) do
      nil -> nil
      room ->
        room.participants
        |> Enum.max_by(&(&1.score || 0), fn -> nil end)
    end
  end

  def reset_game(room_id) do
    case get_room(room_id) do
      nil -> {:error, :not_found}
      room ->
        # Reset scores but keep participants
        participants = Enum.map(room.participants, fn p ->
          %{p | score: 0, hits: 0, misses: 0}
        end)
        update_room(room_id, %{
          participants: participants,
          victim: nil,
          phase: :lobby,
          butt_health: 100,
          timer_seconds: @default_timer_seconds,
          damage_level: 0,
          hit_count: 0
        })
    end
  end

  def delete_room(room_id) do
    :ets.delete(@table, room_id)
    :ok
  end
end
