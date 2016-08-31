defmodule Ode.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :name, :string, [null: false]
      add :type, :string, [null: false]
      add :etag, :string, [null: false]
      add :ctag, :string, [null: false]
      add :mtime, :string, [null: false]
      add :parent_id, references(:items)
      add :crc32, :string
      timestamps
    end

    create index(:items, [:name])
  end
end
