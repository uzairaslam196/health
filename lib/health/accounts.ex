defmodule Health.Accounts do
  @moduledoc """
  The Accounts context for user authentication.
  """

  import Ecto.Query, warn: false
  alias Health.Repo
  alias Health.Accounts.User

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.
  Returns the user if the email exists and the password is valid.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user by id.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by id, returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the role atom for a user.
  """
  def user_role(%User{role: "nutritionist"}), do: :nutritionist
  def user_role(%User{role: "seeker"}), do: :seeker
  def user_role(_), do: :seeker
end
