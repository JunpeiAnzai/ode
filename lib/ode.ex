defmodule Ode do
  def main(args \\ []) do
    config_file_path = "./config.json"

    args
    |> parse_args
    |> process

    config_file_path
    |> read_config
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

  def read_config(path) do
    case File.read(path) do
      {:ok, body} -> IO.puts body
      {:error, reason} -> IO.puts reason
    end
  end
end
