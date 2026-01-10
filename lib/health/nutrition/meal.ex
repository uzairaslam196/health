defmodule Health.Nutrition.Meal do
  use Ecto.Schema
  import Ecto.Changeset

  @meal_types ~w(pre_breakfast breakfast post_breakfast lunch evening_snack dinner)
  @statuses ~w(pending taken missed)

  schema "meals" do
    field :name, :string
    field :meal_type, :string
    field :scheduled_date, :date
    field :scheduled_time, :time
    field :status, :string, default: "pending"
    field :notes, :string

    belongs_to :diet_plan, Health.Nutrition.DietPlan

    timestamps()
  end

  @doc false
  def changeset(meal, attrs) do
    meal
    |> cast(attrs, [:name, :meal_type, :scheduled_date, :scheduled_time, :status, :notes, :diet_plan_id])
    |> validate_required([:name, :meal_type, :scheduled_date, :diet_plan_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:meal_type, @meal_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:diet_plan_id)
  end

  def meal_types, do: @meal_types
  def statuses, do: @statuses

  def meal_type_display("pre_breakfast"), do: "Pre-Breakfast"
  def meal_type_display("breakfast"), do: "Breakfast"
  def meal_type_display("post_breakfast"), do: "Post-Breakfast"
  def meal_type_display("lunch"), do: "Lunch"
  def meal_type_display("evening_snack"), do: "Evening Snack"
  def meal_type_display("dinner"), do: "Dinner"
  def meal_type_display(type), do: type
end
