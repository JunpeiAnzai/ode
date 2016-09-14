defmodule ItemDB do
  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

 @file_type {:file, :dir}
  def insert
  def update
  def upsert
  def selectChildren

  def selectById(id) do
    Item
    |> select([item], item)
    |> where([item], item.id == ^id)
    |> Repo.all
  end

  def selectByPath

  def deleteById(id) do
    result = Repo.get!(Item, id)
    |> Repo.delete

    case result do
      {:ok, _} -> :true
      {:error, _} -> :false
    end
  end

  def hasParent
  def buildItem

  def computePath(id, path \\ []) do
    item = Item
    |> select([item], {item.name, item.parent_id})
    |> where([item], item.id == ^id)
    |> Repo.all

    path = case {item, item.name, item.parent_id} do
             {[], _, _}
               -> []
             {_, _, nil}
               -> case Enum.empty?(path) do
                    :true -> "."
                    :false -> "./" <> path
                  end
               {_, _, _}
               -> case Enum.empty?(path) do
                    :true -> item.name
                    :false -> item.name <> "/" <> path
                  end
           end

    unless Enum.empty?(path) do
      computePath(id, path)
    end
  end
end
