defmodule OctaStar.ActionsTest do
  use ExUnit.Case, async: true

  alias OctaStar.Actions
  alias OctaStar.TestHandlers.PageController

  test "encodes and decodes module names" do
    encoded = Actions.encode_module(PageController)

    assert encoded == "octa_star-test_handlers-page_controller"
    assert Actions.decode_module(encoded) == {:ok, PageController}
  end

  test "generates module action expressions" do
    assert Actions.post(PageController, "increment") ==
             "@post('/ds/octa_star-test_handlers-page_controller/increment')"

    assert Actions.get(PageController, "show", prefix: "/admin") ==
             "@get('/admin/ds/octa_star-test_handlers-page_controller/show')"
  end

  test "generates dynamic action expressions" do
    assert Actions.post("increment") == "@post('/ds/' + $_octa_star_module + '/increment')"
  end

  test "generates form action expressions" do
    assert Actions.form(:post, PageController, "submit", "signup-form") ==
             "@post('/ds/octa_star-test_handlers-page_controller/submit', {contentType: 'form', headers: {'x-csrf-token': $csrf}, selector: '#signup-form'})"
  end
end
