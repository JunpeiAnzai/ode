defmodule OdeTest do
  use ExUnit.Case
  doctest Ode

  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

  test "that should insert and delete item normally" do
    # assert we can insert and query a item
    id = :rand.uniform |> to_string
    mtime = Timex.now |> Timex.to_erl |> Ecto.DateTime.from_erl

    new_item = %Item{name: "item_name",
                     id: id,
                     is_dir: false,
                     etag: "item_etag",
                     ctag: "item_ctag",
                     mtime: mtime,
                     crc32: "item_crc32"
                    }

    {:ok, some_item} = new_item |> Repo.insert

    inserted_id =
      Item
      |> select([item], item.id)
      |> where([item], item.id == ^some_item.id)
      |> Repo.one!

    assert id == inserted_id

    inserted_item = Repo.get!(Item, inserted_id)
    update_sets = %{
      name: "new_item_name",
      is_dir: true,
      etag: "new_item_etag",
      ctag: "new_item_ctag",
      crc32: "new_crc32"
    }

    Ecto.Changeset.change(inserted_item, update_sets)
    |> Repo.update!

    update_item = Repo.get!(Item, inserted_id)

    assert update_item.name == "new_item_name"

    is_deleted =
      Repo.get!(Item, inserted_id)
      |> Repo.delete

    assert elem(is_deleted, 0) == :ok
  end

  test "that should select item by id normally" do
    id = :rand.uniform |> to_string
    mtime = Timex.now |> Timex.to_erl |> Ecto.DateTime.from_erl

    %Item{
      name: "item_name",
      id: id,
      is_dir: false,
      etag: "item_etag",
      ctag: "item_ctag",
      mtime: mtime,
      crc32: "item_crc32"}
      |> Repo.insert

    item = ItemDB.select_by_id(id)

    assert id == item.id

    Repo.get!(Item, id)
    |> Repo.delete!
  end

  test "that should insert item by item and delete item by id normally" do
    id = :rand.uniform |> to_string
    mtime = Timex.now |> Timex.to_erl |> Ecto.DateTime.from_erl

    new_item = %Item{name: "item_name",
                     id: id,
                     is_dir: false,
                     etag: "item_etag",
                     ctag: "item_ctag",
                     mtime: mtime,
                     crc32: "item_crc32"
                    }

    is_inserted? = new_item |> ItemDB.insert

    assert is_inserted?

    update_item = %Item{name: "new_item_name",
                     id: id,
                     is_dir: true,
                     etag: "new_item_etag",
                     ctag: "new_item_ctag",
                     mtime: mtime,
                     crc32: "new_item_crc32"
                    }

    ItemDB.update(update_item)

    updated_item = Repo.get!(Item, id)

    assert updated_item.name == "new_item_name"

    assert ItemDB.delete_by_id(id)
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

  test "that should detect the value imply root directory" do
    value =
      %{
        "name" => "root",
        "parentReference" => %{
          "id" => "23543283219382131!0"
        }
      }

    assert SyncEngine.is_root_dir?(value)
  end

  test "that should compute path properly" do
    mtime = Timex.now |> Timex.to_erl |> Ecto.DateTime.from_erl
    root_id = "root_id"
    sub_id = "sub_id"
    sub_sub_id = "sub_sub_id"
    target_id = "target_id"
    root_dir =
      %Item{
        id: root_id,
        name: "root_name",
        is_dir: true,
        etag: "root_etag",
        ctag: "root_ctag",
        mtime: mtime,
        parent_id: nil,
        crc32: "root_crc"
      }

    sub_dir =
      %Item{
        id: sub_id,
        name: "sub_dir",
        is_dir: true,
        etag: "sub_etag",
        ctag: "sub_ctag",
        mtime: mtime,
        parent_id: "root_id",
        crc32: "sub_crc"
      }

    sub_sub_dir =
      %Item{
        id: sub_sub_id,
        name: "sub_sub_dir",
        is_dir: true,
        etag: "sub_sub_etag",
        ctag: "sub_ctag",
        mtime: mtime,
        parent_id: "sub_id",
        crc32: "sub_sub_crc"
      }

    sub_sub_sub_item =
      %Item{
        id: target_id,
        name: "sub_sub_sub_name",
        is_dir: false,
        etag: "sss_etag",
        ctag: "sss_ctag",
        mtime: mtime,
        parent_id: "sub_sub_id",
        crc32: "sss_crc"
      }

    Repo.delete(root_id)
    Repo.delete(sub_id)
    Repo.delete(sub_sub_id)
    Repo.delete(target_id)
    root_dir |> Repo.insert
    sub_dir |> Repo.insert
    sub_sub_dir |> Repo.insert
    sub_sub_sub_item |> Repo.insert

    assert ItemDB.compute_path(target_id) == "./sub_dir/sub_sub_dir/sub_sub_sub_name"
  end
end
