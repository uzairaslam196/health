defmodule Health.Nutrition.DietPlan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "diet_plans" do
    field :name, :string
    field :description, :string
    field :start_date, :date
    field :end_date, :date

    has_many :meals, Health.Nutrition.Meal

    timestamps()
  end

  @doc false
  def changeset(diet_plan, attrs) do
    diet_plan
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
