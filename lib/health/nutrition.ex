defmodule Health.Nutrition do
  @moduledoc """
  The Nutrition context handles Orbits (practice plans) and Rhythms (daily activities).

  Terminology:
  - Orbit: A tracked practice/routine over a period of time (formerly Diet Plan)
  - Rhythm: A scheduled activity at a specific time of day (formerly Meal)
  """

  import Ecto.Query, warn: false
  alias Health.Repo
  alias Health.Nutrition.{Orbit, Rhythm}

  # =============================================================================
  # ORBITS (formerly Diet Plans)
  # =============================================================================

  @doc """
  Returns the list of orbits.
  """
  def list_orbits do
    Repo.all(from o in Orbit, order_by: [desc: o.start_date])
  end

  # Backward compatibility
  def list_diet_plans, do: list_orbits()

  @doc """
  Gets a single orbit.
  Raises `Ecto.NoResultsError` if the Orbit does not exist.
  """
  def get_orbit!(id), do: Repo.get!(Orbit, id)

  # Backward compatibility
  def get_diet_plan!(id), do: get_orbit!(id)

  @doc """
  Gets a single orbit with rhythms preloaded.
  """
  def get_orbit_with_rhythms!(id) do
    Orbit
    |> Repo.get!(id)
    |> Repo.preload(rhythms: from(r in Rhythm, order_by: [r.scheduled_date, r.scheduled_time]))
  end

  # Backward compatibility
  def get_diet_plan_with_meals!(id), do: get_orbit_with_rhythms!(id) |> Map.put(:meals, Map.get(get_orbit_with_rhythms!(id), :rhythms))

  @doc """
  Creates an orbit.
  """
  def create_orbit(attrs \\ %{}) do
    %Orbit{}
    |> Orbit.changeset(attrs)
    |> Repo.insert()
  end

  # Backward compatibility
  def create_diet_plan(attrs \\ %{}), do: create_orbit(attrs)

  @doc """
  Creates an orbit with auto-generated rhythms for each day in the date range.
  """
  def create_orbit_with_rhythms(attrs, rhythm_types \\ nil) do
    rhythm_types = rhythm_types || Rhythm.rhythm_types()

    Repo.transaction(fn ->
      case create_orbit(attrs) do
        {:ok, orbit} ->
          generate_rhythms_for_orbit(orbit, rhythm_types)
          orbit = get_orbit_with_rhythms!(orbit.id)
          # Add :meals alias for backward compatibility
          Map.put(orbit, :meals, orbit.rhythms)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Creates an orbit with custom rhythm entries (name + type) for each day in the date range.
  """
  def create_orbit_with_custom_rhythms(attrs, rhythm_entries) do
    Repo.transaction(fn ->
      case create_orbit(attrs) do
        {:ok, orbit} ->
          generate_custom_rhythms_for_orbit(orbit, rhythm_entries)
          orbit = get_orbit_with_rhythms!(orbit.id)
          Map.put(orbit, :meals, orbit.rhythms)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  # Backward compatibility
  def create_diet_plan_with_meals(attrs, meal_types \\ nil), do: create_orbit_with_rhythms(attrs, meal_types)

  defp generate_rhythms_for_orbit(%Orbit{} = orbit, rhythm_types) do
    end_date = orbit.end_date || Date.add(orbit.start_date, 6)

    Date.range(orbit.start_date, end_date)
    |> Enum.each(fn date ->
      Enum.each(rhythm_types, fn rhythm_type ->
        create_rhythm(%{
          name: Rhythm.rhythm_display(rhythm_type),
          meal_type: rhythm_type,
          scheduled_date: date,
          diet_plan_id: orbit.id
        })
      end)
    end)
  end

  defp generate_custom_rhythms_for_orbit(%Orbit{} = orbit, rhythm_entries) do
    end_date = orbit.end_date || Date.add(orbit.start_date, 6)

    Date.range(orbit.start_date, end_date)
    |> Enum.each(fn date ->
      Enum.each(rhythm_entries, fn entry ->
        create_rhythm(%{
          name: entry.name,
          meal_type: entry.type,
          notes: Map.get(entry, :notes, ""),
          scheduled_date: date,
          diet_plan_id: orbit.id
        })
      end)
    end)
  end

  @doc """
  Updates an orbit.
  """
  def update_orbit(%Orbit{} = orbit, attrs) do
    orbit
    |> Orbit.changeset(attrs)
    |> Repo.update()
  end

  # Backward compatibility
  def update_diet_plan(orbit, attrs), do: update_orbit(orbit, attrs)

  @doc """
  Deletes an orbit.
  """
  def delete_orbit(%Orbit{} = orbit) do
    Repo.delete(orbit)
  end

  # Backward compatibility
  def delete_diet_plan(orbit), do: delete_orbit(orbit)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking orbit changes.
  """
  def change_orbit(%Orbit{} = orbit, attrs \\ %{}) do
    Orbit.changeset(orbit, attrs)
  end

  # Backward compatibility
  def change_diet_plan(orbit, attrs \\ %{}), do: change_orbit(orbit, attrs)

  # =============================================================================
  # RHYTHMS (formerly Meals)
  # =============================================================================

  @doc """
  Returns the list of rhythms for an orbit.
  """
  def list_rhythms(orbit_id) do
    Rhythm
    |> where([r], r.diet_plan_id == ^orbit_id)
    |> order_by([r], [r.scheduled_date, r.scheduled_time])
    |> Repo.all()
  end

  # Backward compatibility
  def list_meals(diet_plan_id), do: list_rhythms(diet_plan_id)

  @doc """
  Returns rhythms for a specific date.
  """
  def list_rhythms_by_date(date) do
    Rhythm
    |> where([r], r.scheduled_date == ^date)
    |> order_by([r], r.scheduled_time)
    |> Repo.all()
    |> Repo.preload(:orbit)
  end

  # Backward compatibility
  def list_meals_by_date(date) do
    Rhythm
    |> where([r], r.scheduled_date == ^date)
    |> order_by([r], r.scheduled_time)
    |> Repo.all()
    |> Repo.preload(orbit: from(o in Orbit))
    |> Enum.map(fn r -> Map.put(r, :diet_plan, r.orbit) end)
  end

  @doc """
  Returns rhythms for a date range grouped by date.
  """
  def list_rhythms_by_date_range(start_date, end_date) do
    Rhythm
    |> where([r], r.scheduled_date >= ^start_date and r.scheduled_date <= ^end_date)
    |> order_by([r], [r.scheduled_date, r.scheduled_time])
    |> Repo.all()
    |> Repo.preload(:orbit)
    |> Enum.group_by(& &1.scheduled_date)
  end

  # Backward compatibility
  def list_meals_by_date_range(start_date, end_date) do
    Rhythm
    |> where([r], r.scheduled_date >= ^start_date and r.scheduled_date <= ^end_date)
    |> order_by([r], [r.scheduled_date, r.scheduled_time])
    |> Repo.all()
    |> Repo.preload(orbit: from(o in Orbit))
    |> Enum.map(fn r -> Map.put(r, :diet_plan, r.orbit) end)
    |> Enum.group_by(& &1.scheduled_date)
  end

  @doc """
  Gets a single rhythm.
  """
  def get_rhythm!(id), do: Repo.get!(Rhythm, id)

  # Backward compatibility
  def get_meal!(id), do: get_rhythm!(id)

  @doc """
  Creates a rhythm.
  """
  def create_rhythm(attrs \\ %{}) do
    %Rhythm{}
    |> Rhythm.changeset(attrs)
    |> Repo.insert()
  end

  # Backward compatibility
  def create_meal(attrs \\ %{}), do: create_rhythm(attrs)

  @doc """
  Updates a rhythm.
  """
  def update_rhythm(%Rhythm{} = rhythm, attrs) do
    rhythm
    |> Rhythm.changeset(attrs)
    |> Repo.update()
  end

  # Backward compatibility
  def update_meal(rhythm, attrs), do: update_rhythm(rhythm, attrs)

  @doc """
  Marks a rhythm as completed.
  """
  def mark_rhythm_completed(%Rhythm{} = rhythm) do
    update_rhythm(rhythm, %{status: "completed"})
  end

  # Backward compatibility - maps "taken" to "completed"
  def mark_meal_taken(rhythm), do: mark_rhythm_completed(rhythm)

  @doc """
  Marks a rhythm as skipped.
  """
  def mark_rhythm_skipped(%Rhythm{} = rhythm) do
    update_rhythm(rhythm, %{status: "skipped"})
  end

  # Backward compatibility - maps "missed" to "skipped"
  def mark_meal_missed(rhythm), do: mark_rhythm_skipped(rhythm)

  @doc """
  Resets a rhythm to pending.
  """
  def reset_rhythm_status(%Rhythm{} = rhythm) do
    update_rhythm(rhythm, %{status: "pending"})
  end

  # Backward compatibility
  def reset_meal_status(rhythm), do: reset_rhythm_status(rhythm)

  @doc """
  Deletes a rhythm.
  """
  def delete_rhythm(%Rhythm{} = rhythm) do
    Repo.delete(rhythm)
  end

  # Backward compatibility
  def delete_meal(rhythm), do: delete_rhythm(rhythm)

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rhythm changes.
  """
  def change_rhythm(%Rhythm{} = rhythm, attrs \\ %{}) do
    Rhythm.changeset(rhythm, attrs)
  end

  # Backward compatibility
  def change_meal(rhythm, attrs \\ %{}), do: change_rhythm(rhythm, attrs)

  @doc """
  Gets rhythm statistics for an orbit.
  """
  def get_rhythm_stats(orbit_id) do
    query =
      from r in Rhythm,
        where: r.diet_plan_id == ^orbit_id,
        group_by: r.status,
        select: {r.status, count(r.id)}

    stats = Repo.all(query) |> Map.new()

    %{
      total: Map.values(stats) |> Enum.sum(),
      completed: Map.get(stats, "completed", 0),
      skipped: Map.get(stats, "skipped", 0),
      pending: Map.get(stats, "pending", 0),
      # Backward compatibility
      taken: Map.get(stats, "completed", 0) + Map.get(stats, "taken", 0),
      missed: Map.get(stats, "skipped", 0) + Map.get(stats, "missed", 0)
    }
  end

  # Backward compatibility
  def get_meal_stats(diet_plan_id), do: get_rhythm_stats(diet_plan_id)
end
