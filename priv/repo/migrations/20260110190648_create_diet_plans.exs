defmodule Health.Repo.Migrations.CreateDietPlans do
  use Ecto.Migration

  def change do
    create table(:diet_plans) do
      add :name, :string, null: false
      add :description, :text
      add :start_date, :date, null: false
      add :end_date, :date

      timestamps()
    end
  end
end
