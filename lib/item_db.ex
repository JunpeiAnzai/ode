defmodule ItemDB do
  alias Ode.Repo
  alias Ode.Item

  require Logger

  def insert(item) do
    case Repo.insert(item) do
      {:ok, _}
        -> true
      {:error, _}
        -> false
    end
  end
  def update(item) do
    changeset = %{
          name: item.name,
          is_dir: item.is_dir,
          etag: item.etag,
          ctag: item.ctag,
          mtime: item.mtime,
          parent_id: item.parent_id,
          crc32: item.crc32,
    }
    Repo.get!(Item, item.id)
    |> Ecto.Changeset.change(changeset)
    |> Repo.update!
  end
  def upsert
  def select_children

  def select_by_id(id) do
    Repo.get(Item, id)
  end

  def select_by_path

  def delete_by_id(id) do
    result = Repo.get!(Item, id)
    |> Repo.delete

    case result do
      {:ok, _} -> :true
      {:error, _} -> :false
    end
  end

  def has_parent
  def build_item

  def compute_path(id, path \\ "") do
    item = select_by_id(id)

    new_path = cond do
      is_nil(item) ->
        ""
      is_nil(item.parent_id) ->
        if String.length(path) == 0 do
          "."
        else
          "./" <> path
        end
      true ->
        if String.length(path) == 0 do
          item.name
        else
          item.name <> "/" <> path
        end
    end

    new_path =
    if not is_nil(item.parent_id) and String.length(new_path) > 0 do
      compute_path(item.parent_id, new_path)
    else
      new_path
    end
  end
end
