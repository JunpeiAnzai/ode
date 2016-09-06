defmodule SyncEngine do
  defmodule ApiValue do
    @expected_fields_value ~w(
      cTag
      eTag
      file
      fileSystemInfo
      id
      name
      parentReference
    )
    def process_value(value) do
      value
      |> Map.take(@expected_fields_value)
      |> Enum.map(fn{k, v} -> {String.to_atom(k), v} end)
    end
  end

  def apply_differences(pid) do
    require Logger
    Logger.debug "Applying differences"

    delta_token =
      case token_value = TokensServer.get(pid, :delta_token) do
        nil ->
          ""
        _ ->
          token_value
      end
    try do
      IO.puts "try"
      changes =
        OneDriveApi.view_changes_by_path(pid, "/", delta_token)

      changes.body[:value]
      |> apply_difference
      throw(:x)
    catch
      :x ->
        IO.puts "catch x"
    end
  end

  def apply_difference(values) do
    values
    |> List.first
    |> ApiValue.process_value
    |> IO.inspect
  end
end
