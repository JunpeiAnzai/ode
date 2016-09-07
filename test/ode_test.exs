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
end
