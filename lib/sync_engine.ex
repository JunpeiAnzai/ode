defmodule SyncEngine do
  def apply_differences(pid) do
    require Logger
    Logger.debug "Applying differences"

    delta_token =
      case token_value = TokensServer.get(pid, :delta_token) do
        nil -> ""
        _ -> token_value
      end
    try do
      IO.puts "try"
      changes =
        OneDriveApi.view_changes_by_path(pid, "/", delta_token)
      IO.inspect changes

      throw(:x)
    catch
      :x -> IO.puts "catch x"
    end
  end
end
