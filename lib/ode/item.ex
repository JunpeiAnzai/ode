defmodule Ode.Item do
  use Ecto.Model

  @primary_key false
  schema "items" do
    field :file_id, :string, primary_key: true
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
