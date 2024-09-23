defmodule RavensIrisWeb.ErrorJSONTest do
  use RavensIrisWeb.ConnCase, async: true

  test "renders 404" do
    assert RavensIrisWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert RavensIrisWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
