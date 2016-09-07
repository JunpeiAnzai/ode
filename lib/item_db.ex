defmodule ItemDB do
  alias Ode.Repo
  alias Ode.Item

  import Ecto.Query

 @file_type {:file, :dir}
  def insert
  def update
  def upsert
  def selectChildren
  def selectById(file_id) do
    query = from i in Item, select: i, where: i.file_id == ^file_id
    Repo.all(query)
  end
  def selectByPath
  def deleteById
  def hasParent
  def buildItem
  def computePath
end
