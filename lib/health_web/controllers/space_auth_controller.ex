defmodule HealthWeb.SpaceAuthController do
  use HealthWeb, :controller

  alias Health.Accounts

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/space")

      user ->
        conn
        |> put_session(:space_role, user.role)
        |> put_session(:user_id, user.id)
        |> redirect(to: ~p"/space")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:space_role)
    |> redirect(to: ~p"/space")
  end
end
