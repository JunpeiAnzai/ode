defmodule Ode.Item do
  use Ecto.Schema

  @primary_key false
  schema "items" do
    field :id, :string, primary_key: true
    field :
    field :type, :string
    field :etag, :string
    field :ctag, :string
    field :mtime, :string
    field :parent_id, :string
    field :crc32, :string
    timestamps
  end
end
