defmodule StarView.ActionsTest do
  use ExUnit.Case, async: true

  alias StarView.Actions
  alias StarView.TestHandlers.PageController

  test "encodes and decodes module names" do
    encoded = Actions.encode_module(PageController)

    assert encoded == "star_view-test_handlers-page_controller"
    assert Actions.decode_module(encoded) == {:ok, PageController}
  end

  test "generates module action expressions" do
    assert Actions.post(PageController, "increment") ==
              "@post('/ds/star_view-test_handlers-page_controller/increment')"

    assert Actions.get(PageController, "show", prefix: "/admin") ==
             "@get('/admin/ds/star_view-test_handlers-page_controller/show')"
  end

  test "generates dynamic action expressions" do
    assert Actions.post("increment") == "@post('/ds/' + $_star_view_module + '/increment')"
  end
end
