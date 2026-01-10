defmodule HealthWeb.HomeLiveTest do
  use HealthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "home page" do
    test "renders home page with title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Personal Health Tracker"
    end

    test "shows main tagline", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "personal health tracker combined with a nutritionist support space"
    end

    test "displays all feature cards", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h3", "Health Tracking")
      assert has_element?(view, "h3", "Diet Planning")
      assert has_element?(view, "h3", "Nutrition Guidance")
    end

    test "has enter personal space button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "a[href='/space']", "Enter Personal Space")
    end

    test "clicking enter personal space navigates to space", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, _view, html} =
        view
        |> element("a", "Enter Personal Space")
        |> render_click()
        |> follow_redirect(conn, ~p"/space")

      assert html =~ "Sign in to access your wellness journey"
    end

    test "has cosmic theme elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "cosmic-bg"
      assert html =~ "cosmic-button"
      assert html =~ "cosmic-card"
    end
  end
end
