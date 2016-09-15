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
    with {:ok, value} <- pickup(values),
         items = value |> add_cached_tag |> rename_item,
         {:ok} <- skip_item(value),
         {:ok, items} <- detect_item_type(items) do
      items
      |> apply_item
      |> save_item
      IO.puts "picked"
    end
    # with item_length when item_length > 0 <- length(items),
    #      item <- recognize_root_dir(hd(items)),
    #      {:ok, item} <- add_cached_tag(item),
    #      {:ok, item} <- skip_item(item),
    #      {:ok, item} <- rename_item(item),
    #      {:ok, item} <- detect_item_type(item),
    #      {:ok, item} <- apply_item(item),
    #      {:ok} <- save_item(item) do
    #   items
    #   |> tl
    #   |> apply_difference
    # else
    #   {:skip, message} ->
    #     IO.puts message
    #   items
    #   |> tl
    #   |> apply_difference
    # end
  end

  def pickup(values) do
    case length(values) do
      0 -> {:error, :no_values}
      _ -> {:ok, hd(values)}
    end
  end

  def is_root_dir?(value) do
    String.ends_with?(value["parentReference"]["id"], "!0")
  end

  def skip_item(value) do
    skip_list = :ets.lookup(:file_list, :to_skip_id)
    if Enum.member?(skip_list, value["parentReference"]["id"]) do
      skip_list
      |> Tuple.append(value["id"])
      :ets.insert(:file_list, skip_list)
      {:skip}
    else
      {:ok}
    end
  end

  def add_cached_tag(value) do
    old_item = value["id"]
    |> ItemDB.selectById

    Map.new(
      [{:value, value},
       {:old_item, old_item},
       {:is_cached, not Enum.empty?(old_item)}])
  end

  def rename_item(items) do
    # rename the local item if it is unsynced
    # and there is a new version of it
    is_equivalent =
      String.equivalent?(items.old_item[:etag], items.value["eTag"])
    if items.is_cached and not is_equivalent do
      path = ItemDB.computePath(items.old_item[:id])
      unless is_item_synced?(items.old_item, path) do
        Logger.debug "The local item is unsynced, renaming"
        if File.exists?(path) do
          safe_rename(path)
        end
        Map.put(items, :is_cached, false)
      end
    end
    items
  end

  def is_item_synced?(item, path) do
    result = with true <- File.exists?(path) do
               with "file" <- item.type do
                 with {:ok, stat} <- File.lstat(path) do
                   if stat.mtime == item.mtime do
                     true
                   end
                   if crc32(path) == item.crc32 do
                     true
                   end
                 else
                   {:error, _} -> false
                 end
               else
                 "dir" -> File.dir?(path)
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

  def detect_item_type(items) do
    path = if items.value["parentId"] do
      ItemDB.computePath(items.value["parentId"]) <> "/" <> items.value["name"]
    else
      "."
    end

    Map.put(items, :path, path)
    cond do
      Map.has_key?(items.value, "deleted") ->
        if items.is_cached do
          ItemDB.deleteById(items.old_item[:id])
          delete_list =
            :ets.lookup(:file_list, :to_delete)
            |> Tuple.append(ItemDB.computePath(items.old_item[:id]))
          :ets.insert(:file_list, {:to_delete, delete_list})
        end
        {:skip}
      Map.has_key?(items.value, "file") ->
        skip_file_regex = :ets.lookup(:file_list, {:skip_file_regex})
        if String.match?(path, skip_file_regex) do
          {:skip}
        else
          Map.put(items, :type, :file)
          {:ok, items}
        end
      Map.has_key?(items.value, "folder") ->
        skip_dir_regex = :ets.lookup(:file_list, {:skip_dir_regex})
        if String.match?(path, skip_dir_regex) do
          skip_item =
            :ets.lookup(:file_list, :to_skip_id)
            |> Tuple.append(items.value["id"])
          :ets.insert(:file_list, {:to_skip_id, skip_item})
          {:skip}
        else
          Map.put(items, :type, :folder)
          {:ok, items}
        end
      true ->
        IO.puts "unknown"
        skip_item =
          :ets.lookup(:file_list, :to_skip_id)
          |> Tuple.append(items.value["id"])
        :ets.insert(:file_list, {:to_skip_id, skip_item})
        {:skip}
    end
  end

  def apply_item(items) do
    id = items.value["id"]
    name = items.value["name"]
    type = items.type
    etag = items.value["eTag"]
    ctag = items.value["cTag"]
    mtime = items.value["fileSystemInfo"]["lastModifiedDateTime"]
    parent_id = items.value["parentId"]

    crc32 = if items.type == :file do
      items.value["file"]["hashes"]["crc32Hash"]
    end

    new_item = %Ode.Item{
      id: id,
      name: name,
      type: type,
      etag: etag,
      ctag: ctag,
      mtime: mtime,
      parent_id: parent_id,
      crc32: crc32
    }
    unless items.is_cached do
      apply_new_item(new_item, items.path)
      # TODO apply_new_item
      items
    else
      # TODO apply_changed_item(item, new_item)
      items
    end
  end

  def apply_new_item(item, path) do
    with true <- not (File.exists?(path) and is_item_synced?(item, path)) do
      if File.exists?(path) do
        safe_rename(path)
      end
      case item.type do
        :file
          -> OneDriveApi.download_by_id(item.id, path)
        :dir
          -> File.mkdir!(path)
      end
      File.touch!(path, item.mtime)
    else
      false -> File.touch!(path, item.mtime)
    end
  end

  def save_item(value) do
    # TODO
    value
  end
end
