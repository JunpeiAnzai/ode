defmodule SyncEngine do
  require Logger

  def apply_differences(pid) do
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
    and not String.equivalent?(item[:etag], value["eTag"]) do
      path = ItemDB.computePath(item[:id])
      if is_item_synced?(item, path) do
        Logger.debug "The local item is unsynced, renaming"
        if File.exists?(path) do
          safe_rename(path)
        end
      end
    end
    value
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
               {:error, _}
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
    |> :erlang.crc32
    |> Integer.to_string(16)
  end

  def safe_rename(path) do
    device_name = case :inet.gethostname do
                    {:ok, host_name}
                      -> to_string host_name
                    {:error, _}
                      -> Logger.debug "error in safe_rename"
                  end
    ext = Path.extname(path)
    new_path = String.trim_trailing(path, ext) <> "-" <> device_name <> ext
    |> create_new_path

    File.rename(path, new_path)
  end

  defp create_new_path(new_path, n \\ 2) do
    if File.exists?(new_path) do
      ext = Path.extname(new_path)
      new_path = String.trim_trailing(new_path, ext)
      <> "-" <> Integer.to_string(n) <> ext
      create_new_path(new_path, n + 1)
    else
      new_path
    end
  end

  def detect_item_type(value) do
    cond do
      Map.has_key?(value, "deleted") ->
        IO.puts "deleted"
        item =
          value["id"]
          |> ItemDB.selectById
        if not Enum.empty?(item) do
          ItemDB.deleteById(item[:id])
          :ets.insert(:file_list, {:to_delete, ItemDB.computePath(item[:id])})
        end
      Map.has_key?(value, "file") ->
        # TODO skip file if match skip_item
        IO.puts "file"
      Map.has_key?(value, "folder") ->
        # TODO skip dir if match skip_item
        IO.puts "folder"
    end
  end

  def apply_item(value) do
    # TODO
    new_item = %Ode.Item{}

    ctag = value["cTag"]
    %{new_item | ctag: ctag}

    mtime = value["fileSystemInfo"]["lastModifiedDateTime"]
    %{new_item | mtime: mtime}

    id = value["id"]
    %{new_item | id: id}

    name = value["name"]
    %{new_item | name: name}

    type = value["type"]
    %{new_item | type: type}

    etag = value["eTag"]
    %{new_item | etag: etag}

    parent_id = value["parentId"]
    %{new_item | parent_id: parent_id}

    crc32 = value["file"]["hashes"]["crc32Hash"]
    %{new_item | crc32: crc32}
  end

  def save_item(value) do
    # TODO
    value
  end
end
