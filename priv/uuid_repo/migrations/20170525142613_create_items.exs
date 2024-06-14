defmodule PaperTrail.UUIDRepo.Migrations.CreateItems do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:items) do
      add(:item_id, :binary_id, null: false, primary_key: true)
      add(:title, :string, null: false)

      timestamps()
    end

    create table(:foo_items) do
      add(:title, :string, null: false)

      timestamps()
    end

    create table(:bar_items, primary_key: false) do
      add(:item_id, :string, primary_key: true)
      add(:title, :string, null: false)

      timestamps()
    end

    create table(:uuid_items) do
      add(:item_id, :uuid, null: false, primary_key: true)
      add(:title, :string, null: false)

      timestamps()
    end

    create table(:composite_primary_keys_items, primary_key: false) do
      add(:item_id, :uuid, primary_key: true)
      add(:bar_id, :uuid, primary_key: true)

      timestamps()
    end
  end
end
