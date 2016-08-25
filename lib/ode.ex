defmodule Ode do
  def main(args \\ []) do
    args
    |> parse_args
    |> process
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
end
