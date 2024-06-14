defmodule Product do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "products" do
    field(:name, :string)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end

defmodule Admin do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "admins" do
    field(:email, :string)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:email])
    |> validate_required([:email])
  end
end

defmodule Item do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:item_id, :binary_id, autogenerate: true}
  schema "items" do
    field(:title, :string)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:title])
    |> validate_required(:title)
  end
end

defmodule UUIDItem do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:item_id, Ecto.UUID, autogenerate: true}
  schema "uuid_items" do
    field(:title, :string)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:title])
    |> validate_required(:title)
  end
end

defmodule FooItem do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "foo_items" do
    field(:title, :string)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:title])
    |> validate_required(:title)
  end
end

defmodule BarItem do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:item_id, :string, autogenerate: false}
  schema "bar_items" do
    field(:title, :string)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:item_id, :title])
    |> validate_required([:item_id, :title])
  end
end

defmodule CompositePkItem do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  schema "composite_primary_keys_items" do
    field(:item_id, Ecto.UUID, primary_key: true)
    field(:bar_id, Ecto.UUID, primary_key: true)

    timestamps()
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:item_id, :bar_id])
    |> validate_required([:item_id, :bar_id])
  end
end
