defmodule Health.Nutrition.Orbit do
  @moduledoc """
  An Orbit represents a tracked practice/routine over a period of time.
  It contains Rhythms - scheduled activities at different times of day.

  Think of an Orbit as your daily/weekly cycle of practices - like a planet's
  orbit around the sun, your routines cycle through each day.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Keep database schema as "diet_plans" for backward compatibility
  schema "diet_plans" do
    field :name, :string
    field :description, :string
    field :start_date, :date
    field :end_date, :date

    has_many :rhythms, Health.Nutrition.Rhythm, foreign_key: :diet_plan_id

    timestamps()
  end

  @doc false
  def changeset(orbit, attrs) do
    orbit
    |> cast(attrs, [:name, :description, :start_date, :end_date])
    |> validate_required([:name, :start_date])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_dates()
  end

  defp validate_dates(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if start_date && end_date && Date.compare(end_date, start_date) == :lt do
      add_error(changeset, :end_date, "must be after start date")
    else
      changeset
    end
  end
end
