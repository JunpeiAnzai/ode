defmodule ItemDB do
  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

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

  def select_by_path(path, candidates \\ nil) do
    # a path has many candidates

    candidates_list =
    if is_nil candidates do
      new_candidates = {}
      new_path =
        "root/" <> String.trim_leading(path, ".")
        |> Path.basename

      ids = Repo.all(
        from i in Item,
        where: i.name == ^path,
        select: [i.id, i.parent_id]
      )

      new_path = Path.dirname(new_path)
      Tuple.append(new_candidates, ids)

      Keyword.new(path: new_path, candidates: new_candidates)
    else
      Keyword.new(path: path, candidates: candidates)
    end

    candidates_list =
    if candidates_list.path != "." do
      # discard the candidates that do not have the correct parent
      child_path = candidates_list.path
      new_candidates = candidates_list.candidates
      |> Enum.map(fn(candidate) ->
        parent_path = Path.basename(child_path)
        parent_id = tl candidate
        parent_item =
          Repo.one(
            from i in Item,
            where: i.name == ^parent_path and i.id == ^parent_id,
            select: i.parent_id
          )
        [hd(candidate), parent_item]
      end)
      |> Enum.reject(fn(candidate) -> is_nil(tl candidate) end)

      new_path = Path.dirname(child_path)

      Keyword.new(path: new_path, candidates: new_candidates)
    else
      candidates_list
    end

    if path != "." do
      select_by_path(candidates_list.path, candidates_list.candidates)
    end

    # reached the root
    new_candidates =
      candidates_list.candidates
      |> Enum.filter(fn(candidate) -> is_nil(tl candidate) end)

    return_item = if length new_candidates == 1 do
      select_by_id(elem(candidates, 0) |> hd)
    else
      nil
    end

    return_item
  end

  def delete_by_id(id) do
    result =
      Repo.get!(Item, id)
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
          "./#{path}"
        end
      true ->
        if String.length(path) == 0 do
          item.name
        else
          item.name <> "/#{path}"
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
