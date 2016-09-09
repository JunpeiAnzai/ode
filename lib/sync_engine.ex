defmodule SyncEngine do
  require Logger
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
    item =
      value["id"]
      |> ItemDB.selectById

    if not Enum.empty?(item)
    and not String.equivalent?(item[:etag], value["id"]) do
      old_path = ItemDB.computePath(item[:id])
      if is_item_synced?(item, path) do
        Logger.debug "The local item is unsynced, renaming"
        if File.exists?(path) do
          safe_rename(path)
        end
      end
    end
  end

  def is_item_synced?(item, path) do
    result = if File.exists?(path) do
      case item.type do
        "file"
          -> case File.lstat(path) do
               {:ok, stat}
               -> local_mtime = stat.mtime
               if local_mtime == item.mtime do
                 true
               end
               if crc32(path) == item.crc32 do
                 true
               end
               {:error, posix}
               -> false
               _
               -> false
             end
          "dir"
          -> File.dir?(path)
      end
    end
    result
  end

  def crc32(path) do
    File.read!(path)
    |> :erlang.crc32(str)
    |> Integer.to_string(16)
  end

  def safe_rename(path) do
    device_name = :inet.gethostname
    ext = Path.extname(path)
    new_path = String.trim_trailing(path, ext) <> "-" <> device_name
    if File.exists?(new_path) do
      n = 2
      new_path2 = ""

      new_path2 = new_path <> "-" <> Integer.to_string(n)
      n = n + 1


    end
      
    end
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
