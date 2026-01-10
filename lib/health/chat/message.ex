defmodule Health.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(nutritionist seeker)

  schema "messages" do
    field :content, :string
    field :sender_role, :string

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :sender_role])
    |> validate_required([:content, :sender_role])
    |> validate_length(:content, min: 1, max: 5000)
    |> validate_inclusion(:sender_role, @roles)
  end

  def roles, do: @roles
end
