defmodule SyncEngine do
  require Logger

  defmodule Items do
    defstruct value: nil, old_item: nil, is_dir: false, path: nil, is_cached: false
  end

  def apply_differences do
    Logger.debug "Applying differences"

    delta_token =
      case token_value = :ets.lookup(:tokens, :delta_token) do
        [] ->
          ""
        _ ->
          Keyword.get(token_value, :delta_token)
      end
    try do
      IO.puts "try"
      changes =
        OneDriveApi.view_changes_by_path("/", delta_token)

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
         {:ok, typed_items} <- detect_item_type(items) do
      typed_items
      |> apply_item

      apply_difference(tl(values))
    else
      {:skip} -> apply_difference(tl(values))
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
    value["name"] == "root"
    and
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
    |> ItemDB.select_by_id

    %Items{
      value: value,
      old_item: old_item,
      is_cached: not is_nil(old_item)
    }
  end

  def rename_item(items) do
    # rename the local item if it is unsynced
    # and there is a new version of it
    is_renamed = false
    is_renamed =
    if items.is_cached and not is_equivalent?(items) do
      path = ItemDB.compute_path(items.old_item[:id])
      unless is_item_synced?(items.old_item, path) do
        Logger.debug "The local item is unsynced, renaming"
        if File.exists?(path) do
          safe_rename(path)
        end
        true
      end
    end
    items = if is_renamed do
      %{items | is_cached: false}
    else
      items
    end
    items
  end

  def is_equivalent?(items) do
    String.equivalent?(items.old_item.etag, items.value["eTag"])
  end

  def is_item_synced?(item, path) do
    File.exists?(path) and
    if item.is_dir do
      File.dir?(path)
    else
      case File.lstat(path) do
        {:ok, stat} ->
          cond do
            stat.mtime == item.mtime -> true
            crc32(path) == item.crc32 -> true
            true -> false
          end
        {:error, _} ->
          false
      end
    end
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
    parent_id = items.value["parentReference"]["id"]
    IO.puts items.value["name"]
    path = if not is_root_dir?(items.value) do
      ItemDB.compute_path(parent_id) <> "/" <> items.value["name"]
    else
      "."
    end
    |> Path.expand

    items = %{items | path: path}
    cond do
      Map.has_key?(items.value, "deleted") ->
        if items.is_cached do
          ItemDB.delete_by_id(items.old_item[:id])
          delete_list =
            :ets.lookup(:file_list, :to_delete)
            |> Tuple.append(ItemDB.compute_path(items.old_item[:id]))
          :ets.insert(:file_list, {:to_delete, delete_list})
        end
        {:skip}
      Map.has_key?(items.value, "file") ->
        skip_file_regex =
          Keyword.get(
            :ets.lookup(:file_list, {:skip_file_regex}), :skip_file_regex)
        if not is_nil(skip_file_regex) and String.match?(path, skip_file_regex) do
          {:skip}
        else
          items = %{items | is_dir: false}
          {:ok, items}
        end
      Map.has_key?(items.value, "folder") ->
        skip_dir_regex =
          Keyword.get(
            :ets.lookup(:file_list, {:skip_dir_regex}), :skip_dir_regex)
        if not is_nil(skip_dir_regex) and String.match?(path, skip_dir_regex) do
          skip_item =
            :ets.lookup(:file_list, :to_skip_id)
            |> Tuple.append(items.value["id"])
          :ets.insert(:file_list, {:to_skip_id, skip_item})
          {:skip}
        else
          items = %{items | is_dir: true}
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
    is_dir = items.is_dir
    etag = items.value["eTag"]
    ctag = items.value["cTag"]
    mtime = items.value["fileSystemInfo"]["lastModifiedDateTime"]
    |> Timex.parse!("{ISO:Extended:Z}")
    |> Timex.local
    |> Timex.to_erl
    |> Ecto.DateTime.from_erl
    parent_id = items.value["parentId"]

    crc32 = unless items.is_dir do
      items.value["file"]["hashes"]["crc32Hash"]
    end

    new_item = %Ode.Item{
      id: id,
      name: name,
      is_dir: is_dir,
      etag: etag,
      ctag: ctag,
      mtime: mtime,
      parent_id: parent_id,
      crc32: crc32
    }
    unless items.is_cached do
      apply_new_item(new_item, items.path)
    else
      apply_changed_item(items.old_item, new_item, items.path)
    end

    unless is_nil(items.old_item) do
      ItemDB.update(new_item)
    else
      ItemDB.insert(new_item)
    end

  end

  def apply_new_item(item, path) do
    Logger.debug "applying new item"
    with true <- File.exists?(path) and is_item_synced?(item, path) do
      Logger.debug "file exists and synced"
      File.touch!(path, Ecto.DateTime.to_erl(item.mtime))
    else
      false ->
      if File.exists?(path) do
        safe_rename(path)
      end
      if item.is_dir do
        File.mkdir!(path)
      else
        OneDriveApi.download_by_id(item.id, path)
      end
      File.touch!(path, Ecto.DateTime.to_erl(item.mtime))
    end
  end

  def apply_changed_item(old_item, new_item, new_path) do
    if old_item.etag != new_item.etag do
      old_path = ItemDB.compute_path(old_item.id)
      if old_path != new_path do
        Logger.debug "Moving"
        if File.exists?(new_path) do
          Logger.debug "The destination is occupied, renaming"
          safe_rename(new_path)
        end
        File.rename(old_path, new_path)
      end

      if not new_item.is_dir and old_item.ctag != new_item.ctag do
        Logger.debug "downliading"
        OneDriveApi.download_by_id(new_item.id, new_path)
      end
      File.touch!(new_path, Ecto.DateTime.to_erl(new_item.mtime))
    else
      Logger.debug "The item has not changed"
    end
  end
end
