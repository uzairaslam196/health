defmodule HealthWeb.SpaceLiveTest do
  use HealthWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Helper to authenticate by setting session
  defp authenticate(conn, role) do
    Plug.Test.init_test_session(conn, %{"space_role" => role})
  end

  describe "Login" do
    test "shows login form when not authenticated", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/space")

      assert html =~ "Enter Personal Space"
      assert html =~ "Sign in to access your wellness journey"
      assert has_element?(view, "input[name='email']")
      assert has_element?(view, "input[name='password']")
      assert has_element?(view, "button", "Enter Space")
    end

    test "shows error for invalid credentials via controller", %{conn: conn} do
      conn = post(conn, ~p"/space/login", %{email: "invalid@test.com", password: "wrong"})

      assert redirected_to(conn) == "/space"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end

    test "authenticates nutritionist with valid credentials via controller", %{conn: conn} do
      # Create user for test
      {:ok, _user} = Health.Accounts.create_user(%{
        email: "nutritionist@test.com",
        password: "testpass123",
        role: "nutritionist"
      })

      conn = post(conn, ~p"/space/login", %{email: "nutritionist@test.com", password: "testpass123"})

      assert redirected_to(conn) == "/space"
      assert get_session(conn, :space_role) == "nutritionist"
    end

    test "authenticates health seeker with valid credentials via controller", %{conn: conn} do
      # Create user for test
      {:ok, _user} = Health.Accounts.create_user(%{
        email: "seeker@test.com",
        password: "testpass123",
        role: "seeker"
      })

      conn = post(conn, ~p"/space/login", %{email: "seeker@test.com", password: "testpass123"})

      assert redirected_to(conn) == "/space"
      assert get_session(conn, :space_role) == "seeker"
    end

    test "back to home link works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/space")

      assert has_element?(view, "a[href='/']", "Back to Home")
    end
  end

  describe "authenticated navigation" do
    setup %{conn: conn} do
      conn = authenticate(conn, "nutritionist")
      {:ok, view, _html} = live(conn, ~p"/space")

      %{view: view, conn: conn}
    end

    test "shows dashboard by default", %{view: view} do
      assert has_element?(view, "h1", "Welcome, Nutritionist")
    end

    test "shows nutritionist role badge", %{view: view} do
      assert has_element?(view, "span", "Nutritionist")
      assert has_element?(view, "span", "Personal Space")
    end

    test "can navigate to orbits tab", %{view: view} do
      view
      |> element("nav a[href='/space?tab=plans']")
      |> render_click()

      assert has_element?(view, "h2", "Your Orbits")
    end

    test "can navigate to routine tab", %{view: view} do
      view
      |> element("nav a[href='/space?tab=meals']")
      |> render_click()

      assert has_element?(view, "h2", "Daily Routine")
    end

    test "can navigate to messages tab", %{view: view} do
      view
      |> element("nav a[href='/space?tab=messages']")
      |> render_click()

      assert has_element?(view, "h2", "Messages")
    end

    test "logout link exists", %{view: view} do
      assert has_element?(view, "a[href='/space/logout']")
    end
  end

  describe "health seeker authentication" do
    setup %{conn: conn} do
      conn = authenticate(conn, "seeker")
      {:ok, view, _html} = live(conn, ~p"/space")

      %{view: view}
    end

    test "shows health seeker role badge", %{view: view} do
      assert has_element?(view, "span", "Health Seeker")
    end
  end

  describe "orbits management" do
    setup %{conn: conn} do
      conn = authenticate(conn, "nutritionist")
      {:ok, view, _html} = live(conn, ~p"/space?tab=plans")

      %{view: view}
    end

    test "shows empty state when no orbits exist", %{view: view} do
      assert has_element?(view, "h3", "No Orbits Yet")
      assert has_element?(view, "button", "Create Your First Orbit")
    end

    test "can open new orbit form", %{view: view} do
      view
      |> element("button", "New Orbit")
      |> render_click()

      assert has_element?(view, "h2", "Create New Orbit")
      assert has_element?(view, "input[name='orbit[name]']")
    end

    test "can create an orbit", %{view: view} do
      view
      |> element("button", "New Orbit")
      |> render_click()

      view
      |> form("form", %{
        orbit: %{
          name: "Test Orbit",
          description: "A test orbit",
          start_date: "2026-01-15"
        }
      })
      |> render_submit()

      # After creation, should navigate to orbit detail view
      assert has_element?(view, "h2", "Test Orbit")
    end

    test "validates required fields", %{view: view} do
      view
      |> element("button", "New Orbit")
      |> render_click()

      view
      |> form("form", %{orbit: %{name: "", start_date: ""}})
      |> render_change()

      assert has_element?(view, "p", "can't be blank")
    end
  end

  describe "messaging" do
    setup %{conn: conn} do
      conn = authenticate(conn, "nutritionist")
      {:ok, view, _html} = live(conn, ~p"/space?tab=messages")

      %{view: view}
    end

    test "shows empty state when no messages", %{view: view} do
      assert has_element?(view, "p", "No messages yet")
    end

    test "shows role indicator", %{view: view} do
      assert has_element?(view, "span", "Chatting as Nutritionist")
    end

    test "can send a message", %{view: view} do
      view
      |> form("form[phx-submit='send_message']", %{message: "Hello, how are you?"})
      |> render_submit()

      assert has_element?(view, "p", "Hello, how are you?")
      assert has_element?(view, "span", "Nutritionist")
    end

    test "can toggle emoji picker", %{view: view} do
      # Emoji picker should be hidden initially
      refute has_element?(view, "button[title='Health']")

      view
      |> element("button[phx-click='toggle_emojis']")
      |> render_click()

      # Now emoji buttons should be visible
      assert has_element?(view, "button[title='Health']")
    end

    test "send button is disabled when message is empty", %{view: view} do
      assert has_element?(view, "button[disabled][type='submit']")
    end
  end
end
