defmodule Mix.Tasks.StarView.Trust do
  @shortdoc "Adds the StarView dev host and generates an mkcert certificate"

  @moduledoc """
  Adds the configured StarView development host to `/etc/hosts` and generates a
  browser-trusted development certificate with `mkcert`.

  The task infers the host from:

      config :my_app, star_view: [dev_url: "https://my-app.test:4001"]

  If no `:dev_url` is configured, it falls back to the current Mix application
  name with underscores converted to hyphens.

  This task asks before running local machine setup. If accepted, it may prompt
  for your password through `sudo` when updating `/etc/hosts` or when `mkcert`
  installs its local certificate authority.

  `mkcert` must be installed first. On macOS:

      brew install mkcert nss

  ## Examples

      mix star_view.trust
      mix star_view.trust --host my-app.test
      mix star_view.trust --cert priv/cert/selfsigned.pem
      mix star_view.trust --key priv/cert/selfsigned_key.pem
      mix star_view.trust --yes

  ## Options

    * `--host` - hostname to add and generate a certificate for. Defaults to
      the configured StarView dev URL host.
    * `--cert` - certificate path. Defaults to `priv/cert/selfsigned.pem`.
    * `--key` - private key path. Defaults to `priv/cert/selfsigned_key.pem`.
    * `--ip` - IP address for the hosts entry. Defaults to `127.0.0.1`.
    * `--dry-run` - print the commands without running them.
    * `--yes` - skip the confirmation prompt.
  """

  use Mix.Task

  @default_cert_path "priv/cert/selfsigned.pem"
  @default_key_path "priv/cert/selfsigned_key.pem"
  @default_hosts_file "/etc/hosts"
  @default_ip "127.0.0.1"

  @switches [
    cert: :string,
    dry_run: :boolean,
    host: :string,
    hosts_file: :string,
    ip: :string,
    key: :string,
    yes: :boolean
  ]
  @aliases [c: :cert, h: :host]

  @impl Mix.Task
  def run(argv) do
    Mix.Task.run("app.config")

    {options, args, invalid} = OptionParser.parse(argv, strict: @switches, aliases: @aliases)
    validate_args!(args, invalid)

    app_name = Mix.Project.config() |> Keyword.fetch!(:app)
    host = Keyword.get(options, :host) || configured_host(app_name) || dev_host(app_name)
    ip = Keyword.get(options, :ip, @default_ip)
    cert_path = options |> Keyword.get(:cert, @default_cert_path) |> Path.expand()
    key_path = options |> Keyword.get(:key, @default_key_path) |> Path.expand()
    hosts_file = Keyword.get(options, :hosts_file, @default_hosts_file)
    dry_run? = Keyword.get(options, :dry_run, false)
    yes? = Keyword.get(options, :yes, false)

    validate_host!(host)
    validate_ip!(ip)

    if confirmed?(host, yes?, dry_run?) do
      ensure_mkcert!(dry_run?)
      install_mkcert_ca(dry_run?)
      add_hosts_entry(host, ip, hosts_file, dry_run?)
      generate_certificate(host, cert_path, key_path, dry_run?)

      Mix.shell().info("""
      StarView trust setup complete for https://#{host}.

      Restart `mix dev` if it was already running, and restart your browser if
      it cached the previous certificate error.
      """)
    else
      Mix.shell().info("Skipped StarView trust setup. You can run `mix star_view.trust` later.")
    end
  end

  @doc false
  def configured_host(app_name) do
    app_name_dev_url =
      app_name
      |> Application.get_env(:star_view, [])
      |> Keyword.get(:dev_url)

    package_dev_url = Application.get_env(:star_view, :dev_url)

    host_from_dev_url(app_name_dev_url) || host_from_dev_url(package_dev_url)
  end

  @doc false
  def dev_host(app_name) do
    app_name
    |> to_string()
    |> String.replace("_", "-")
    |> Kernel.<>(".test")
  end

  @doc false
  def host_from_dev_url(nil), do: nil

  def host_from_dev_url(dev_url) when is_binary(dev_url) do
    case URI.parse(dev_url) do
      %URI{host: host} when is_binary(host) and host != "" -> host
      _ -> nil
    end
  end

  def host_from_dev_url(_), do: nil

  @doc false
  def hosts_entry_ip(contents, host) do
    contents
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      line
      |> strip_hosts_comment()
      |> String.split()
      |> case do
        [ip | aliases] ->
          if host in aliases, do: ip

        _ ->
          nil
      end
    end)
  end

  @doc false
  def hosts_append_command(host, ip, hosts_file) do
    entry = "#{ip} #{host}"

    "printf '\\n%s\\n' #{shell_quote(entry)} >> #{shell_quote(hosts_file)}"
  end

  @doc false
  def mkcert_certificate_args(host, cert_path, key_path) do
    [
      "-cert-file",
      cert_path,
      "-key-file",
      key_path,
      host,
      "localhost",
      "127.0.0.1",
      "::1"
    ]
  end

  defp add_hosts_entry(host, ip, hosts_file, dry_run?) do
    case File.read(hosts_file) do
      {:ok, contents} ->
        case hosts_entry_ip(contents, host) do
          ^ip ->
            Mix.shell().info("#{host} already exists in #{hosts_file}.")

          nil ->
            append_hosts_entry(host, ip, hosts_file, dry_run?)

          existing_ip ->
            Mix.shell().error("""
            #{host} already exists in #{hosts_file} with IP #{existing_ip}.
            Leaving it unchanged.
            """)
        end

      {:error, reason} ->
        Mix.shell().error("Could not read #{hosts_file}: #{:file.format_error(reason)}")
        append_hosts_entry(host, ip, hosts_file, dry_run?)
    end
  end

  defp append_hosts_entry(host, ip, hosts_file, dry_run?) do
    Mix.shell().info("Adding #{host} to #{hosts_file} with sudo.")

    run_command(
      "sudo",
      ["-p", "Password: ", "/bin/sh", "-c", hosts_append_command(host, ip, hosts_file)],
      dry_run?
    )
  end

  defp install_mkcert_ca(dry_run?) do
    Mix.shell().info("Installing the local mkcert certificate authority if needed.")
    run_command("mkcert", ["-install"], dry_run?)
  end

  defp generate_certificate(host, cert_path, key_path, dry_run?) do
    ensure_certificate_directory!(cert_path, key_path, dry_run?)

    Mix.shell().info("""
    Generating mkcert certificate for #{host}, localhost, 127.0.0.1, and ::1.
    Certificate: #{cert_path}
    Key: #{key_path}
    """)

    run_command(
      "mkcert",
      mkcert_certificate_args(host, cert_path, key_path),
      dry_run?
    )
  end

  defp confirmed?(_host, true, _dry_run?), do: true
  defp confirmed?(_host, _yes?, true), do: true

  defp confirmed?(host, _yes?, _dry_run?) do
    Mix.shell().info(prompt_intro(host))
    confirm(prompt_question())
  end

  @doc false
  def prompt_intro(host) do
    """
    StarView can add `#{host}` to your hosts file and generate a
    browser-trusted HTTPS certificate with mkcert.
    This lets your browser open `https://#{host}` without certificate errors.
    This may require sudo privileges for `/etc/hosts` and mkcert's local CA
    installation.
    """
  end

  @doc false
  def prompt_question() do
    "Proceed with StarView trust setup? [Y/n] "
  end

  defp confirm(prompt) do
    case IO.gets(prompt) do
      nil ->
        false

      answer ->
        answer
        |> String.trim()
        |> String.downcase()
        |> case do
          "" ->
            true

          yes when yes in ["y", "yes"] ->
            true

          no when no in ["n", "no"] ->
            false

          _ ->
            Mix.shell().info("Please enter y or n.")
            confirm(prompt)
        end
    end
  end

  defp run_command(command, args, true) do
    Mix.shell().info("Would run: #{format_command(command, args)}")
  end

  defp run_command(command, args, false) do
    command = format_command(command, args)

    case Mix.shell().cmd(command) do
      0 ->
        :ok

      status ->
        Mix.raise("Command failed with status #{status}: #{command}")
    end
  end

  defp validate_args!([], []), do: :ok

  defp validate_args!(args, invalid) do
    details =
      []
      |> maybe_add_args_error(args)
      |> maybe_add_invalid_error(invalid)
      |> Enum.join("\n")

    Mix.raise(details)
  end

  defp maybe_add_args_error(errors, []), do: errors

  defp maybe_add_args_error(errors, args) do
    ["Unexpected arguments: #{Enum.join(args, " ")}" | errors]
  end

  defp maybe_add_invalid_error(errors, []), do: errors

  defp maybe_add_invalid_error(errors, invalid) do
    invalid =
      Enum.map_join(invalid, ", ", fn
        {option, nil} -> option
        {option, value} -> "#{option}=#{value}"
      end)

    ["Invalid options: #{invalid}" | errors]
  end

  defp ensure_mkcert!(true), do: :ok

  defp ensure_mkcert!(false) do
    if !System.find_executable("mkcert") do
      Mix.raise("""
      `mkcert` was not found.

      Install it first, then rerun this command:

          brew install mkcert nss
          mix star_view.trust
      """)
    end
  end

  defp ensure_certificate_directory!(cert_path, key_path, true) do
    [cert_path, key_path]
    |> Enum.map(&Path.dirname/1)
    |> Enum.uniq()
    |> Enum.each(&Mix.shell().info("Would create directory: #{&1}"))
  end

  defp ensure_certificate_directory!(cert_path, key_path, false) do
    [cert_path, key_path]
    |> Enum.map(&Path.dirname/1)
    |> Enum.uniq()
    |> Enum.each(&File.mkdir_p!/1)
  end

  defp validate_host!(host) do
    if Regex.match?(
         ~r/^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i,
         host
       ) do
      :ok
    else
      Mix.raise("Invalid DNS hostname for StarView trust setup: #{inspect(host)}")
    end
  end

  defp validate_ip!(ip) do
    ip
    |> String.to_charlist()
    |> :inet.parse_address()
    |> case do
      {:ok, _} -> :ok
      {:error, _} -> Mix.raise("Invalid IP address for StarView trust setup: #{inspect(ip)}")
    end
  end

  defp strip_hosts_comment(line) do
    line
    |> String.split("#", parts: 2)
    |> List.first()
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end

  defp format_command(command, args) do
    [command | args]
    |> Enum.map_join(" ", &shell_quote/1)
  end
end
