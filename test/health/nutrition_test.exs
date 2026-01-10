defmodule Health.NutritionTest do
  use Health.DataCase, async: true

  alias Health.Nutrition
  alias Health.Nutrition.{Orbit, Rhythm}

  describe "orbits" do
    @valid_attrs %{name: "Morning Wellness", description: "A wellness routine", start_date: ~D[2026-01-01], end_date: ~D[2026-03-31]}
    @update_attrs %{name: "Updated Orbit", description: "Updated description"}
    @invalid_attrs %{name: nil, start_date: nil}

    def orbit_fixture(attrs \\ %{}) do
      {:ok, orbit} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Nutrition.create_orbit()

      orbit
    end

    test "list_orbits/0 returns all orbits" do
      orbit = orbit_fixture()
      assert Nutrition.list_orbits() == [orbit]
    end

    test "get_orbit!/1 returns the orbit with given id" do
      orbit = orbit_fixture()
      assert Nutrition.get_orbit!(orbit.id) == orbit
    end

    test "create_orbit/1 with valid data creates an orbit" do
      assert {:ok, %Orbit{} = orbit} = Nutrition.create_orbit(@valid_attrs)
      assert orbit.name == "Morning Wellness"
      assert orbit.description == "A wellness routine"
      assert orbit.start_date == ~D[2026-01-01]
      assert orbit.end_date == ~D[2026-03-31]
    end

    test "create_orbit/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Nutrition.create_orbit(@invalid_attrs)
    end

    test "create_orbit/1 with end_date before start_date returns error" do
      attrs = %{name: "Test", start_date: ~D[2026-03-01], end_date: ~D[2026-01-01]}
      assert {:error, changeset} = Nutrition.create_orbit(attrs)
      assert "must be after start date" in errors_on(changeset).end_date
    end

    test "update_orbit/2 with valid data updates the orbit" do
      orbit = orbit_fixture()
      assert {:ok, %Orbit{} = updated} = Nutrition.update_orbit(orbit, @update_attrs)
      assert updated.name == "Updated Orbit"
      assert updated.description == "Updated description"
    end

    test "update_orbit/2 with invalid data returns error changeset" do
      orbit = orbit_fixture()
      assert {:error, %Ecto.Changeset{}} = Nutrition.update_orbit(orbit, @invalid_attrs)
      assert orbit == Nutrition.get_orbit!(orbit.id)
    end

    test "delete_orbit/1 deletes the orbit" do
      orbit = orbit_fixture()
      assert {:ok, %Orbit{}} = Nutrition.delete_orbit(orbit)
      assert_raise Ecto.NoResultsError, fn -> Nutrition.get_orbit!(orbit.id) end
    end

    test "change_orbit/1 returns an orbit changeset" do
      orbit = orbit_fixture()
      assert %Ecto.Changeset{} = Nutrition.change_orbit(orbit)
    end

    test "create_orbit_with_rhythms/1 creates orbit with auto-generated rhythms" do
      attrs = %{name: "Auto Rhythms Orbit", start_date: ~D[2026-01-15], end_date: ~D[2026-01-17]}

      assert {:ok, %Orbit{} = orbit} = Nutrition.create_orbit_with_rhythms(attrs)
      assert orbit.name == "Auto Rhythms Orbit"

      # 3 days * 7 rhythm types = 21 rhythms
      assert length(orbit.rhythms) == 21

      # Check that rhythms are created for each date
      dates = orbit.rhythms |> Enum.map(& &1.scheduled_date) |> Enum.uniq()
      assert ~D[2026-01-15] in dates
      assert ~D[2026-01-16] in dates
      assert ~D[2026-01-17] in dates

      # Check all rhythm types are created
      rhythm_types = orbit.rhythms |> Enum.map(& &1.meal_type) |> Enum.uniq() |> Enum.sort()
      assert rhythm_types == ["afternoon", "dawn", "evening", "late_night", "midday", "morning", "night"]
    end

    test "create_orbit_with_rhythms/1 defaults to 7 days when no end_date" do
      attrs = %{name: "Week Orbit", start_date: ~D[2026-01-15]}

      assert {:ok, %Orbit{} = orbit} = Nutrition.create_orbit_with_rhythms(attrs)

      # 7 days * 7 rhythm types = 49 rhythms
      assert length(orbit.rhythms) == 49
    end

    test "create_orbit_with_rhythms/2 allows custom rhythm types" do
      attrs = %{name: "Simple Orbit", start_date: ~D[2026-01-15], end_date: ~D[2026-01-15]}
      rhythm_types = ["morning", "evening", "night"]

      assert {:ok, %Orbit{} = orbit} = Nutrition.create_orbit_with_rhythms(attrs, rhythm_types)

      # 1 day * 3 rhythm types = 3 rhythms
      assert length(orbit.rhythms) == 3
    end

    test "create_orbit_with_rhythms/1 with invalid data returns error" do
      attrs = %{name: nil, start_date: nil}
      assert {:error, _changeset} = Nutrition.create_orbit_with_rhythms(attrs)
    end

    test "all rhythms start with pending status" do
      attrs = %{name: "Test Orbit", start_date: ~D[2026-01-15], end_date: ~D[2026-01-15]}

      {:ok, orbit} = Nutrition.create_orbit_with_rhythms(attrs)

      assert Enum.all?(orbit.rhythms, &(&1.status == "pending"))
    end
  end

  describe "rhythms" do
    @valid_rhythm_attrs %{name: "Morning meditation", meal_type: "morning", scheduled_date: ~D[2026-01-15], scheduled_time: ~T[08:00:00], notes: "Quiet space"}
    @update_rhythm_attrs %{name: "Evening reflection", notes: "Before sleep"}
    @invalid_rhythm_attrs %{name: nil, meal_type: nil, scheduled_date: nil}

    def rhythm_fixture(attrs \\ %{}) do
      orbit = orbit_fixture()

      {:ok, rhythm} =
        attrs
        |> Enum.into(@valid_rhythm_attrs)
        |> Map.put(:diet_plan_id, orbit.id)
        |> Nutrition.create_rhythm()

      rhythm
    end

    test "list_rhythms/1 returns all rhythms for an orbit" do
      rhythm = rhythm_fixture()
      assert Nutrition.list_rhythms(rhythm.diet_plan_id) == [rhythm]
    end

    test "list_rhythms_by_date/1 returns rhythms for a specific date" do
      rhythm = rhythm_fixture()
      rhythms = Nutrition.list_rhythms_by_date(~D[2026-01-15])
      assert length(rhythms) == 1
      assert hd(rhythms).id == rhythm.id
    end

    test "list_rhythms_by_date/1 returns empty list for date with no rhythms" do
      _rhythm = rhythm_fixture()
      assert Nutrition.list_rhythms_by_date(~D[2026-12-25]) == []
    end

    test "list_rhythms_by_date_range/2 returns rhythms grouped by date" do
      orbit = orbit_fixture()

      {:ok, _} = Nutrition.create_rhythm(%{
        name: "Day 1 Morning",
        meal_type: "morning",
        scheduled_date: ~D[2026-01-15],
        diet_plan_id: orbit.id
      })

      {:ok, _} = Nutrition.create_rhythm(%{
        name: "Day 1 Evening",
        meal_type: "evening",
        scheduled_date: ~D[2026-01-15],
        diet_plan_id: orbit.id
      })

      {:ok, _} = Nutrition.create_rhythm(%{
        name: "Day 2 Morning",
        meal_type: "morning",
        scheduled_date: ~D[2026-01-16],
        diet_plan_id: orbit.id
      })

      result = Nutrition.list_rhythms_by_date_range(~D[2026-01-15], ~D[2026-01-17])

      assert Map.has_key?(result, ~D[2026-01-15])
      assert Map.has_key?(result, ~D[2026-01-16])
      assert length(result[~D[2026-01-15]]) == 2
      assert length(result[~D[2026-01-16]]) == 1
    end

    test "list_rhythms_by_date_range/2 returns empty map for range with no rhythms" do
      _rhythm = rhythm_fixture()
      result = Nutrition.list_rhythms_by_date_range(~D[2026-12-01], ~D[2026-12-31])
      assert result == %{}
    end

    test "get_rhythm!/1 returns the rhythm with given id" do
      rhythm = rhythm_fixture()
      assert Nutrition.get_rhythm!(rhythm.id) == rhythm
    end

    test "create_rhythm/1 with valid data creates a rhythm" do
      orbit = orbit_fixture()
      attrs = Map.put(@valid_rhythm_attrs, :diet_plan_id, orbit.id)

      assert {:ok, %Rhythm{} = rhythm} = Nutrition.create_rhythm(attrs)
      assert rhythm.name == "Morning meditation"
      assert rhythm.meal_type == "morning"
      assert rhythm.status == "pending"
    end

    test "create_rhythm/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Nutrition.create_rhythm(@invalid_rhythm_attrs)
    end

    test "create_rhythm/1 with invalid rhythm type returns error" do
      orbit = orbit_fixture()
      attrs = @valid_rhythm_attrs |> Map.put(:diet_plan_id, orbit.id) |> Map.put(:meal_type, "invalid")

      assert {:error, changeset} = Nutrition.create_rhythm(attrs)
      assert "is invalid" in errors_on(changeset).meal_type
    end

    test "update_rhythm/2 with valid data updates the rhythm" do
      rhythm = rhythm_fixture()
      assert {:ok, %Rhythm{} = updated} = Nutrition.update_rhythm(rhythm, @update_rhythm_attrs)
      assert updated.name == "Evening reflection"
      assert updated.notes == "Before sleep"
    end

    test "mark_rhythm_completed/1 updates status to completed" do
      rhythm = rhythm_fixture()
      assert {:ok, %Rhythm{} = updated} = Nutrition.mark_rhythm_completed(rhythm)
      assert updated.status == "completed"
    end

    test "mark_rhythm_skipped/1 updates status to skipped" do
      rhythm = rhythm_fixture()
      assert {:ok, %Rhythm{} = updated} = Nutrition.mark_rhythm_skipped(rhythm)
      assert updated.status == "skipped"
    end

    test "reset_rhythm_status/1 updates status to pending" do
      rhythm = rhythm_fixture()
      {:ok, completed_rhythm} = Nutrition.mark_rhythm_completed(rhythm)
      assert {:ok, %Rhythm{} = reset} = Nutrition.reset_rhythm_status(completed_rhythm)
      assert reset.status == "pending"
    end

    test "delete_rhythm/1 deletes the rhythm" do
      rhythm = rhythm_fixture()
      assert {:ok, %Rhythm{}} = Nutrition.delete_rhythm(rhythm)
      assert_raise Ecto.NoResultsError, fn -> Nutrition.get_rhythm!(rhythm.id) end
    end

    test "get_rhythm_stats/1 returns correct statistics" do
      orbit = orbit_fixture()

      # Create multiple rhythms with different statuses
      {:ok, _} = Nutrition.create_rhythm(%{name: "Rhythm 1", meal_type: "morning", scheduled_date: ~D[2026-01-15], diet_plan_id: orbit.id})
      {:ok, rhythm2} = Nutrition.create_rhythm(%{name: "Rhythm 2", meal_type: "evening", scheduled_date: ~D[2026-01-15], diet_plan_id: orbit.id})
      {:ok, rhythm3} = Nutrition.create_rhythm(%{name: "Rhythm 3", meal_type: "night", scheduled_date: ~D[2026-01-15], diet_plan_id: orbit.id})

      Nutrition.mark_rhythm_completed(rhythm2)
      Nutrition.mark_rhythm_skipped(rhythm3)

      stats = Nutrition.get_rhythm_stats(orbit.id)

      assert stats.total == 3
      assert stats.pending == 1
      assert stats.completed == 1
      assert stats.skipped == 1
    end
  end
end
