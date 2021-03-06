defmodule SyncEngine do
  require Logger

  defmodule Items do
    defstruct value: nil, old_item: nil, is_dir: false, path: nil, is_cached: false, is_root: false
  end

  @threshold_file_size 10 * :math.pow(2, 20) # 10 MiB

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
      changes =
        OneDriveApi.view_changes_by_path("/", delta_token)

      changes.body["value"]
      |> apply_difference
      throw(:x)
    catch
      :x ->
        Logger.debug "catch x"
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
      {:skip} ->
        apply_difference(tl(values))
      {:error, :no_values} ->
        Logger.debug "error in apply_difference"
    end
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
      is_cached: not is_nil(old_item),
      is_root: is_root_dir?(value)
    }
  end

  def rename_item(items) do
    # rename the local item if it is unsynced
    # and there is a new version of it
    is_renamed =
    if items.is_cached and not is_equivalent?(items) do
      path = ItemDB.compute_path(items.old_item.id)
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
  end

  def is_equivalent?(items) do
    String.equivalent?(items.old_item.etag, items.value["eTag"])
  end

  def is_item_synced?(item, path) do
    File.exists?(path) and
    if item.is_dir do
      File.dir?(path)
    else
      {:ok, stat} = File.lstat(path)
      case File.lstat(path) do
        {:ok, stat} ->
          cond do
           stat.mtime == Ecto.DateTime.to_erl(item.mtime) ->
              Logger.debug "fs time = db time"
              true
            crc32(path) == item.crc32 ->
              Logger.debug "fs crc = db crc"
              true
            true ->
              Logger.debug "not synced"
              IO.inspect stat.mtime
              IO.inspect item.mtime
              IO.inspect crc32(path)
              IO.inspect item.crc32
              false
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
    |> String.pad_leading(8, "0")
    |> String.to_charlist
    |> Stream.chunk(2)
    |> Enum.to_list
    |> Enum.reverse
    |> List.to_string
  end

  def safe_rename(path) do
    device_name = case :inet.gethostname do
                    {:ok, host_name}
                      -> to_string host_name
                    {:error, _}
                      -> Logger.debug "error in safe_rename"
                  end
    ext = Path.extname(path)
    new_path = String.trim_trailing(path, ext) <> "-#{device_name}#{ext}"
    |> create_new_path

    File.rename(path, new_path)
  end

  defp create_new_path(new_path, n \\ 2) do
    new_path = if File.exists?(new_path) do
      ext = Path.extname(new_path)
      new_path = String.trim_trailing(new_path, ext)
      <> "-" <> Integer.to_string(n) <> ext
      Logger.debug "new path is: #{new_path}"
      create_new_path(new_path, n + 1)
    else
      new_path
    end
  end

  def detect_item_type(items) do
    path = unless items.is_root do
      parent_id = items.value["parentReference"]["id"]
      ItemDB.compute_path(parent_id) <> "/" <> items.value["name"]
    else
      "."
    end

    items = %{items | path: path}
    cond do
      Map.has_key?(items.value, "deleted") ->
        if items.is_cached do
          ItemDB.delete_by_id(items.old_item.id)
          delete_list =
            :ets.lookup(:file_list, :to_delete)
            |> Tuple.append(ItemDB.compute_path(items.old_item.id))
          :ets.insert(:file_list, {:to_delete, delete_list})
        end
        {:skip}
      Map.has_key?(items.value, "file") ->
        skip_file_regex =
          Keyword.get(
            :ets.lookup(:file_list, {:skip_file_regex}), :skip_file_regex)
        if String.match?(path, skip_file_regex) do
          {:skip}
        else
          items = %{items | is_dir: false}
          {:ok, items}
        end
      Map.has_key?(items.value, "folder") ->
        skip_dir_regex =
          Keyword.get(
            :ets.lookup(:file_list, {:skip_dir_regex}), :skip_dir_regex)
        if String.match?(path, skip_dir_regex) do
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
        Logger.debug "unknown file type"
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
    mtime =
      items.value["fileSystemInfo"]["lastModifiedDateTime"]
      |> Timex.parse!("{ISO:Extended:Z}")
      |> Timex.local
      |> Timex.to_erl
      |> Ecto.DateTime.from_erl
    parent_id = unless items.is_root do
      items.value["parentReference"]["id"]
    end
    crc32 = unless items.is_dir do
      items.value["file"]["hashes"]["crc32Hash"]
    end

    new_item =
      %Ode.Item{
        id: id,
        name: name,
        is_dir: is_dir,
        etag: etag,
        ctag: ctag,
        mtime: mtime,
        parent_id: parent_id,
        crc32: crc32
      }

    if items.is_cached do
      apply_changed_item(items.old_item, new_item, items.path)
    else
      apply_new_item(new_item, items.path)
    end

    if is_nil(items.old_item) do
      ItemDB.insert(new_item)
    else
      ItemDB.update(new_item)
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
        Logger.debug "renaming"
        safe_rename(path)
      end
      if item.is_dir do
        File.mkdir!(path)
      else
        Logger.debug "downloading"
        OneDriveApi.download_by_id(item.id, path)
      end
      File.touch!(path, Ecto.DateTime.to_erl(item.mtime))
    end
  end

  def apply_changed_item(old_item, new_item, new_path) do
    Logger.debug "applying changed item"
    if old_item.etag != new_item.etag do
      old_path = ItemDB.compute_path(old_item.id)
      if old_path != new_path do
        Logger.debug "Moving from #{old_path} to #{new_path}"
        if File.exists?(new_path) do
          Logger.debug "The destination is occupied, renaming"
          safe_rename(new_path)
        end
        File.rename(old_path, new_path)
      end

      if not new_item.is_dir and old_item.ctag != new_item.ctag do
        Logger.debug "downloading"
        OneDriveApi.download_by_id(new_item.id, new_path)
      end
      File.touch!(new_path, Ecto.DateTime.to_erl(new_item.mtime))
    else
      Logger.debug "The item has not changed"
    end
  end

  def scan_for_differences(path \\ ".") do
    Logger.debug "Uploading differences"
    case ItemDB.select_by_path(path) do
      {:ok, item}
        -> upload_differences(item)
      _
        -> upload_new_items(path)
    end
  end

  def upload_differences(item) do
    Logger.debug item.id <> " " <> item.name
    path = ItemDB.compute_path(item.id)
    skip_regex = if item.is_dir do
      Keyword.get(
        :ets.lookup(
          :file_list, {:skip_dir_regex}), :skip_dir_regex)
    else
      Keyword.get(
        :ets.lookup(
          :file_list, {:skip_file_regex}), :skip_file_regex)
    end

    unless String.match?(path, skip_regex) do
      if item.is_dir do
        upload_dir_differences(item, path)
      else
        upload_file_differences(item, path)
      end
    end
  end

  def upload_dir_differences(item, path) do
    if File.exists?(path) do
      if File.dir?(path) do
        upload_delete_item(item, path)
        upload_new_file(path)
      else
        ItemDB.select_children(item.id)
        |> Enum.each(fn(item) -> item |> upload_differences end)
      end
    else
      upload_delete_item(item, path)
    end
  end

  def upload_file_differences(item, path) do
    if File.exists?(path) do
      unless File.dir?(path) do
        stat = File.lstat!(path)
        unless stat.mtime == item.mtime |> Ecto.DateTime.to_erl do
          Logger.debug "The file last modified time has changed"
          item = unless crc32(path) == item.crc32 do
            Logger.debug "The file content has changed"
            Logger.debug "Uploading: #{path}"
            #    if stat.size <= @threshold_file_size do
            new_item =
              OneDriveApi.simple_upload(path, path)
              |> parse_response
            #    else
            #      Session.upload(path, path)
            #    end
            save_item(new_item)

            new_item
          end
          upload_last_modified_time(item, stat.mtime)
        else
          Logger.debug "The file has not changed"
        end
      else
        Logger.debug "The item was a file but now is a directory"
        upload_delete_item(item, path)
        upload_create_dir(path)
      end
    else
      Logger.debug "The file has been deleted"
      upload_delete_item(item, path)
    end
  end

  def parse_response(response) do
    id = response["id"]
    is_dir = Map.has_key?(response, "folder")
    name = response["name"]
    etag = response["eTag"]
    ctag = response["cTag"]
    mtime =
      response["fileSystemInfo"]["lastModifiedDateTime"]
      |> Timex.parse!("{ISO:Extended:Z}")
      |> Timex.local
      |> Timex.to_erl
      |> Ecto.DateTime.from_erl
    parent_id = response["parentReference"]["id"]
    crc32 = unless is_dir do
      response["file"]["hashes"]["crc32Hash"]
    end

    %Ode.Item{
      id: id,
      is_dir: is_dir,
      name: name,
      etag: etag,
      ctag: ctag,
      mtime: mtime,
      parent_id: parent_id,
      crc32: crc32
    }
  end

  def upload_delete_item(item, path) do
    Logger.debug "Deleting remote item: #{path}"

    OneDriveApi.delete_by_id(item.id, item.etag)

    ItemDB.delete_by_id(item.id)
  end

  def upload_new_file(path) do
    Logger.debug "Uploading: #{path}"
    stat = File.lstat!(path)
#    if stat.size <= @threshold_file_size do
    new_item =
      OneDriveApi.simple_upload(path, path)
      |> parse_response
#    else
#      Session.upload(path, path)
#    end

    save_item(new_item)

    upload_last_modified_time(new_item, stat.mtime) # stat.mtime is utc
  end

  def save_item(item) do
    item
    |> ItemDB.upsert
  end

  def upload_last_modified_time(item, mtime) do
    mtime_iso = mtime |> DateTime.to_iso8601
    mtime_info = [
      "fileSystemInfo": [
        "lastModifiedDateTime": mtime_iso
      ]]
    |> Poison.encode!

    OneDriveApi.update_by_id(item.id, mtime_info, item.ctag)
    |> parse_response
    |> save_item
  end

  def upload_create_dir(path) do
    Logger.debug "Creating remote directory: #{path}"
    name = Path.basename(path)
    body = [
      name: name,
      folder: nil
    ]
    |> Poison.encode!

    remote_name = Path.dirname(path) <> "/"
    OneDriveApi.create_by_path(remote_name, body)
    |> parse_response
    |> save_item
  end

  def upload_new_items(path) do
    if File.exists?(path) do
      skip_regex = if File.dir?(path) do
        Keyword.get(
          :ets.lookup(
            :file_list, {:skip_dir_regex}), :skip_dir_regex)
      else
        Keyword.get(
          :ets.lookup(
            :file_list, {:skip_file_regex}), :skip_file_regex)
      end

      unless String.match?(path, skip_regex) do
        if File.dir?(path) do
          unless is_nil(ItemDB.select_by_path(path)) do
            upload_create_dir(path)
          end
          Path.split(path)
          |> Enum.each(fn(dir_name) ->
            dir_name
            |> upload_new_items
          end)
        else
          unless is_nil(ItemDB.select_by_path(path)) do
            upload_new_file(path)
          end
        end
      end
    end
  end
end
