defmodule Ode do
  use Application

  @config_file_path "./config.json"

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Ode.Repo, [])
    ]

    opts = [strategy: :one_for_one, name: Ode.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def main(args \\ []) do

    args
    |> parse_args
    |> process

    read_config

    {:ok, pid} = TokensServer.start_link
    pid
    |> Tokens.read_token
  end

  def parse_args(args) do
    options =
      args
      |> OptionParser.parse()
    elem(options, 0)
  end

  def process([]) do
    IO.puts "No arguments"
  end

  def process(options) do
    case hd options do
      {:debug, true} -> IO.puts "debug"
      {:monitor, true} -> IO.puts "monitor"
      _ -> IO.puts "another"
    end
    process (tl options)
  end

  def read_config() do
    case File.read(@config_file_path) do
      {:ok, body} -> IO.puts body
      {:error, reason} -> IO.puts reason
    end
  end
end
