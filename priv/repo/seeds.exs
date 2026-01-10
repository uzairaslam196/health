# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Health.Repo.insert!(%Health.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Health.Accounts

# Create users if they don't exist
users = [
  %{email: "nutritionist@health.app", password: "health123", role: "nutritionist"},
  %{email: "seeker@health.app", password: "health123", role: "seeker"}
]

for user_attrs <- users do
  case Accounts.get_user_by_email(user_attrs.email) do
    nil ->
      {:ok, user} = Accounts.create_user(user_attrs)
      IO.puts("Created user: #{user.email} (#{user.role})")

    _user ->
      IO.puts("User already exists: #{user_attrs.email}")
  end
end
