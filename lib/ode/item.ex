defmodule Ode.Item do
  use Ecto.Schema

  @primary_key false
  schema "items" do
    field :id, :string, primary_key: true
    field :name, :string
    field :is_dir, :boolean
    field :etag, :string
    field :ctag, :string
    field :mtime, Ecto.DateTime
    field :parent_id, :string
    field :crc32, :string
    timestamps
  end

  def changeset(item, params \\ %{}) do
    item
    |> Ecto.Changeset.cast(params,
    [
      :name,
      :is_dir,
      :etag,
      :ctag,
      :mtime,
      :parent_id,
      :crc32
    ])
  end
end
