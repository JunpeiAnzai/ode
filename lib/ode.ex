defmodule Ode do
  use Application
  require Logger

  @config_file_path "./config.json"
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

    config = read_config

    :ets.new(:tokens, [:set, :protected, :named_table])
    OneDriveApi.read_token

    :ets.new(:file_list, [:set, :protected, :named_table])

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
    elem(options, 0)
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

  def read_config() do
    case File.read(@config_file_path) do
      {:ok, body} ->
        Poison.decode!(body)
      {:error, reason} ->
        reason
    end
  end

  def perform_sync(retry_count) do
    SyncEngine.apply_differences

    unless retry_count == 0 do
      perform_sync(retry_count - 1)
    end
  end
end
