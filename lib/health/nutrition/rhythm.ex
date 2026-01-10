defmodule Health.Nutrition.Rhythm do
  @moduledoc """
  Rhythm represents a scheduled activity/practice within an Orbit.
  Rhythms are time-based slots that can be tracked throughout the day.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Time-based rhythm types - compatible with any schedule including night owls
  @rhythm_types ~w(dawn morning midday afternoon evening night late_night)
  @statuses ~w(pending completed skipped)

  # Keep database schema as "meals" for backward compatibility
  schema "meals" do
    field :name, :string
    field :meal_type, :string  # Maps to rhythm_type in the UI
    field :scheduled_date, :date
    field :scheduled_time, :time
    field :status, :string, default: "pending"
    field :notes, :string

    belongs_to :orbit, Health.Nutrition.Orbit, foreign_key: :diet_plan_id

    timestamps()
  end

  @doc false
  def changeset(rhythm, attrs) do
    rhythm
    |> cast(attrs, [:name, :meal_type, :scheduled_date, :scheduled_time, :status, :notes, :diet_plan_id])
    |> validate_required([:name, :meal_type, :scheduled_date, :diet_plan_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:meal_type, @rhythm_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:diet_plan_id)
  end

  def rhythm_types, do: @rhythm_types
  def statuses, do: @statuses

  # For backward compatibility
  def meal_types, do: @rhythm_types

  @doc """
  Returns human-readable display name for rhythm type.
  """
  def rhythm_display("dawn"), do: "Dawn"
  def rhythm_display("morning"), do: "Morning"
  def rhythm_display("midday"), do: "Midday"
  def rhythm_display("afternoon"), do: "Afternoon"
  def rhythm_display("evening"), do: "Evening"
  def rhythm_display("night"), do: "Night"
  def rhythm_display("late_night"), do: "Late Night"
  def rhythm_display(type), do: type |> String.replace("_", " ") |> String.capitalize()

  # Alias for backward compatibility
  def meal_type_display(type), do: rhythm_display(type)

  @doc """
  Returns emoji/icon for rhythm type - cosmic themed.
  """
  def rhythm_icon("dawn"), do: "sunrise"
  def rhythm_icon("morning"), do: "sun"
  def rhythm_icon("midday"), do: "sunny"
  def rhythm_icon("afternoon"), do: "cloudy"
  def rhythm_icon("evening"), do: "sunset"
  def rhythm_icon("night"), do: "moon"
  def rhythm_icon("late_night"), do: "stars"
  def rhythm_icon(_), do: "sparkles"

  @doc """
  Returns order for sorting rhythms throughout the day.
  """
  def rhythm_order("dawn"), do: 1
  def rhythm_order("morning"), do: 2
  def rhythm_order("midday"), do: 3
  def rhythm_order("afternoon"), do: 4
  def rhythm_order("evening"), do: 5
  def rhythm_order("night"), do: 6
  def rhythm_order("late_night"), do: 7
  def rhythm_order(_), do: 8
end
