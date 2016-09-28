defmodule Ode do
  use Application
  require Logger

  @config_file_path "./conf"
  @config_skip_dir "skip_dir"
  @config_skip_file "skip_file"

  @sync_dir_path "~/ode_sync"

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

    :ets.new(:file_list, [:set, :protected, :named_table])
    config = read_config

    :ets.new(:tokens, [:set, :protected, :named_table])
    OneDriveApi.read_token


    Logger.debug "Opening the item database"

    sync_dir = Path.expand(@sync_dir_path)
    unless File.exists?(sync_dir) do
      File.mkdir!(sync_dir)
    end
    File.cd!(sync_dir)

    Logger.debug "Initializing the Synchronization Engine"
    retry_count = 0
    perform_sync(retry_count)

  end

  def parse_args(args) do
    options =
      args
      |> OptionParser.parse()
      |> elem(0)
  end

  def process([]) do
    Logger.debug "No arguments"
  end

  def process(options) do
    case hd options do
      {:debug, true} ->
        Logger.debug "debug mode"
      {:monitor, true} ->
        Logger.debug "monitor mode"
      _ ->
        Logger.debug "another mode"
    end
    process (tl options)
  end

  def read_config do
    File.stream!(@config_file_path)
    |> Stream.each(fn(line) ->
      cond do
        String.starts_with?(line, @config_skip_dir) ->
          skip_dir =
            line
            |> String.trim
            |> String.trim_leading(@config_skip_dir <> "=")
          :ets.insert(:file_list, {:skip_dir_regex, skip_dir})
        String.starts_with?(line, @config_skip_file) ->
          skip_file =
            line
            |> String.trim
            |> String.trim_leading(@config_skip_file <> "=")
          :ets.insert(:file_list, {:skip_file_regex, skip_file})
      end
    end)
    |> Stream.run
  end

  def perform_sync(retry_count) do
    SyncEngine.apply_differences

    SyncEngine.scan_for_differences
    unless retry_count == 0 do
      perform_sync(retry_count - 1)
    end
  end
end
