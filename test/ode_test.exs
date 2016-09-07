defmodule OdeTest do
  use ExUnit.Case
  doctest Ode

  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

  test "that should insert item normally" do
    # assert we can insert and query a user
    file_id = :rand.uniform |> to_string
    {:ok, some_item} = %Item{name: "item_name",
                             file_id: file_id,
                             type: "item_type",
                             etag: "item_etag",
                             ctag: "item_ctag",
                             mtime: "item_mtime",
                             crc32: "item_crc32"}
                          |> Repo.insert
    [file_id] =
      Item
      |> select([item], item.file_id)
      |> where([item], item.file_id == ^some_item.file_id)
      |> Repo.all
  end
end
