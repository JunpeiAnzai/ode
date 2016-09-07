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
  def deleteById
  def hasParent
  def buildItem
  def computePath
end
