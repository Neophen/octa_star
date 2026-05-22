defmodule Mix.Tasks.StarView.TrustTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.StarView.Trust

  setup do
    on_exit(fn ->
      Application.delete_env(:star_view_demo, :star_view)
      Application.delete_env(:star_view, :dev_url)
    end)
  end

  test "hyphenates fallback host from app name" do
    assert Trust.dev_host(:star_view_demo) == "star-view-demo.test"
  end

  test "reads host from app-specific StarView dev URL" do
    Application.put_env(:star_view_demo, :star_view, dev_url: "https://demo.test:4001")

    assert Trust.configured_host(:star_view_demo) == "demo.test"
  end

  test "falls back to package-level dev URL" do
    Application.put_env(:star_view, :dev_url, "https://legacy.test:4001")

    assert Trust.configured_host(:star_view_demo) == "legacy.test"
  end

  test "finds hosts entries while ignoring comments" do
    contents = """
    127.0.0.1 localhost
    # 127.0.0.1 ignored.test
    127.0.0.1 demo.test alias.test # comment
    """

    assert Trust.hosts_entry_ip(contents, "demo.test") == "127.0.0.1"
    assert Trust.hosts_entry_ip(contents, "alias.test") == "127.0.0.1"
    assert Trust.hosts_entry_ip(contents, "ignored.test") == nil
  end

  test "builds hosts append command with shell quoting" do
    assert Trust.hosts_append_command("demo.test", "127.0.0.1", "/tmp/hosts") ==
             "printf '\\n%s\\n' '127.0.0.1 demo.test' >> '/tmp/hosts'"
  end

  test "builds macOS trust command args" do
    assert Trust.trust_args("demo.test", "/tmp/selfsigned.pem") == [
             "security",
             "add-trusted-cert",
             "-d",
             "-r",
             "trustRoot",
             "-p",
             "ssl",
             "-s",
             "demo.test",
             "-k",
             "/Library/Keychains/System.keychain",
             "/tmp/selfsigned.pem"
           ]
  end

  test "keeps the interactive options on the final prompt line" do
    assert Trust.prompt_intro("demo.test") =~
             "StarView can add `demo.test` to your hosts file"

    assert Trust.prompt_question() == "Proceed with StarView trust setup? [Y/n] "
  end
end
