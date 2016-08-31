defmodule OdeTest do
  use ExUnit.Case
  doctest Ode

  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

  setup_all do
    {:ok, pid} = Ode.start(nil, nil)
    {:ok, [pid: pid]}
  end

  test "that should insert item normally" do
    # assert we can insert and query a user
    name = :rand.uniform |> to_string
    {:ok, some_item} = %Item{name: name,
                          type: "item_type",
                          etag: "item_etag",
                          ctag: "item_ctag",
                          mtime: "item_mtime",
                          crc32: "item_crc32"}
                          |> Repo.insert
    [name] =
      Item
      |> select([item], item.name)
      |> where([item], item.name == ^some_item.name)
      |> Repo.all
  end
end
