defmodule Health.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :role, :string, default: "seeker"

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration/creation.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role])
    |> validate_required([:email, :password])
    |> validate_email()
    |> hash_password()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:email)
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        # Simple hash for demo purposes - in production use Bcrypt
        hashed = :crypto.hash(:sha256, password) |> Base.encode64()
        put_change(changeset, :hashed_password, hashed)
    end
  end

  @doc """
  Verifies the password against the hashed password.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    # Simple hash verification
    :crypto.hash(:sha256, password) |> Base.encode64() == hashed_password
  end

  def valid_password?(_, _), do: false
end
