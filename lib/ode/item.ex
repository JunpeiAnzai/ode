defmodule Ode.Item do
  use Ecto.Model

  schema "items" do
    field :name, :string
    field :type, :string
    field :etag, :string
    field :ctag, :string
    field :mtime, :string
    field :parent_id, :string
    field :crc32, :string
    timestamps
  end
end
