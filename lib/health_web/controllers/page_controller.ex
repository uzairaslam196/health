defmodule HealthWeb.PageController do
  use HealthWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
