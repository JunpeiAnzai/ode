defmodule OdeTest do
  use ExUnit.Case
  doctest Ode

  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

  test "that should insert item normally" do
    # assert we can insert and query a user
    id = :rand.uniform |> to_string
    {:ok, some_item} = %Item{name: "item_name",
                             id: id,
                             type: "item_type",
                             etag: "item_etag",
                             ctag: "item_ctag",
                             mtime: "item_mtime",
                             crc32: "item_crc32"}
                          |> Repo.insert
    [file_id] =
      Item
      |> select([item], item.id)
      |> where([item], item.id == ^some_item.id)
      |> Repo.all
  end

  test "that should rename the file" do
    file_name = :rand.uniform |> to_string

    ext = ".testext"
    device_name = case :inet.gethostname do
                    {:ok, host_name}
                      -> to_string host_name
                    _
                      -> "error"
                  end

    new_file_name = file_name <> "-" <> device_name <> ext
    path = "~/" <> file_name <> ext
    |> Path.expand
    new_path = "~/" <> new_file_name
    |> Path.expand
    if not File.exists?(path) and not File.exists?(new_path) do
      File.touch!(path)
      SyncEngine.safe_rename(path)
      assert File.exists?(new_path)

      File.rm!(new_path)
    end
  end

  test "that should rename the file name A to B-2 when file B is exist" do
    file_name = :rand.uniform |> to_string

    ext = ".testext"
    device_name = case :inet.gethostname do
                    {:ok, host_name}
                      -> to_string host_name
                    _
                      -> "error"
                  end
    new_file_name = file_name <> "-" <> device_name <> ext
    new_file_name2 = file_name <> "-" <> device_name <> "-2" <> ext
    path = "~/" <> file_name <> ext
    |> Path.expand
    new_path = "~/" <> new_file_name
    |> Path.expand
    new_path2 = "~/" <> new_file_name2
    |> Path.expand
    if not File.exists?(path) and not File.exists?(new_path) and not File.exists?(new_path2) do
      File.touch!(path)
      File.touch!(new_path)
      SyncEngine.safe_rename(path)
      assert File.exists?(new_path2)

      File.rm!(new_path)
      File.rm!(new_path2)
    end
  end
end
