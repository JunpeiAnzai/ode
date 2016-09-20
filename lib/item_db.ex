defmodule ItemDB do
  alias Ode.Repo
  alias Ode.Item

  require Logger

  def insert(item) do
    Repo.insert!(item)
  end
  def update(item) do
    changeset = Item.changeset(item, %{
          name: item.name,
          is_dir: item.is_dir,
          etag: item.etag,
          ctag: item.ctag,
          mtime: item.mtime,
          parent_id: item.parent_id,
          crc32: item.crc32
                               })
    Repo.update!(changeset)
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
    Logger.debug "initial path:" <> path
    item = select_by_id(id)

    new_path = cond do
      is_nil(item) ->
        ""
      is_nil(item.parent_id) ->
        Logger.debug "parent directory is root"
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

    Logger.debug "processed path:" <> new_path
    IO.inspect item.parent_id

    if not is_nil(item.parent_id) and String.length(new_path) > 0 do
      compute_path(item.parent_id, new_path)
    end
    new_path
  end
end
