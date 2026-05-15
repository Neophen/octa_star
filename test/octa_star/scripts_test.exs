defmodule OctaStar.ScriptsTest do
  use ExUnit.Case, async: true

  alias OctaStar.Scripts

  test "formats execute script as an append-to-body element patch" do
    assert Scripts.format_execute("console.log('hello')", auto_remove: false) ==
             """
             event: datastar-patch-elements
             data: selector body
             data: mode append
             data: elements <script>console.log('hello')</script>

             """
  end

  test "auto-removes scripts by default and escapes closing script tags" do
    assert Scripts.format_execute("document.body.innerHTML = '</script>'") ==
             """
             event: datastar-patch-elements
             data: selector body
             data: mode append
             data: elements <script data-effect="el.remove()">document.body.innerHTML = '<\\/script>'</script>

             """
  end
end
