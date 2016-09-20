defmodule Ode.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, [null: false]
      add :is_dir, :boolean, [null: false]
      add :etag, :string, [null: false]
      add :ctag, :string, [null: false]
      add :mtime, :datetime, [null: false]
      add :parent_id, references(:items, [column: :id, type: :string])
      add :crc32, :string
      timestamps
    end

    create index(:items, [:name])
  end
end
