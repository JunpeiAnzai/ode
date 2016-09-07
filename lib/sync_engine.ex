defmodule SyncEngine do
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

      changes.body["value"]
      |> apply_difference
      throw(:x)
    catch
      :x ->
        IO.puts "catch x"
    end
  end

  def apply_difference(values) do
    if length(values) !== 0 do
      values
      |> hd
      |> recognize_root_dir
      |> skip_item
      |> rename_item
      |> compute_path
      |> detect_item_type
      |> apply_item
      |> save_item

      values
      |> tl
      |> apply_difference
    end
  end

  def recognize_root_dir(value) do
    if String.ends_with?(value["parentReference"]["id"], "!0") do
      Map.put(value["parentReference"], "id", :root_dir)
    end
    value
  end

  def skip_item(value) do
    # TODO
    value
  end

  def rename_item(value) do
    # rename the local item if it is unsynced
    # and there is a new version of it
    # TODO
    value["id"]
    |> ItemDB.selectById
  end

  def compute_path(value) do
    # TODO
    value
  end

  def detect_item_type(value) do
    # TODO
    value
  end

  def apply_item(value) do
    # TODO
    value
  end

  def save_item(value) do
    # TODO
    value
  end
end
