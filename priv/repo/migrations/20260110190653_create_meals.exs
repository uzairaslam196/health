defmodule Health.Repo.Migrations.CreateMeals do
  use Ecto.Migration

  def change do
    create table(:meals) do
      add :name, :string, null: false
      add :meal_type, :string, null: false
      add :scheduled_date, :date, null: false
      add :scheduled_time, :time
      add :status, :string, default: "pending"
      add :notes, :text
      add :diet_plan_id, references(:diet_plans, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:meals, [:diet_plan_id])
    create index(:meals, [:scheduled_date])
    create index(:meals, [:status])
  end
end
