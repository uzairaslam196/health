defmodule HealthWeb.PageControllerTest do
  use HealthWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Personal Health Tracker"
  end

  test "GET / shows home page content", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "personal health tracker combined with a nutritionist support space"
    assert response =~ "Enter Personal Space"
    assert response =~ "Health Tracking"
    assert response =~ "Diet Planning"
    assert response =~ "Nutrition Guidance"
  end

  test "GET /space shows login form", %{conn: conn} do
    conn = get(conn, ~p"/space")
    response = html_response(conn, 200)
    assert response =~ "Enter Personal Space"
    assert response =~ "Sign in to access your wellness journey"
  end
end
