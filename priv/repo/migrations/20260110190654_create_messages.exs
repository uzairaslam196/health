defmodule Health.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text, null: false
      add :sender_role, :string, null: false

      timestamps()
    end

    create index(:messages, [:sender_role])
    create index(:messages, [:inserted_at])
  end
end
