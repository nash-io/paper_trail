defmodule Repo.Migrations.CreateSimpleCompanies do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:simple_companies) do
      add(:name, :string, null: false)
      add(:is_active, :boolean)
      add(:website, :string)
      add(:city, :string)
      add(:address, :string)
      add(:facebook, :string)
      add(:twitter, :string)
      add(:founded_in, :string)
      add(:location, :map)
      add(:email_options, :map)
      add(:addresses, :map)

      timestamps()
    end
  end
end
