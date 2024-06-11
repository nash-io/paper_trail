defmodule PaperTrail.Version do
  @moduledoc "Ecto schema that represents a version of a record at a point of time."
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  @originator_type Application.compile_env(:paper_trail, :originator_type, :integer)
  @origin_read_after_writes Application.compile_env(:paper_trail, :origin_read_after_writes, true)
  @item_id_type Application.compile_env(:paper_trail, :item_type, :integer)

  @type t :: %__MODULE__{
          event: String.t(),
          item_type: String.t(),
          item_id: any,
          item_changes: map,
          originator_id: any,
          meta: map
        }

  schema "versions" do
    field(:event, :string)
    field(:item_type, :string)
    field(:item_id, @item_id_type)
    field(:item_changes, :map)
    field(:originator_id, @originator_type)

    field(:origin, :string, read_after_writes: @origin_read_after_writes)

    field(:meta, :map)

    if PaperTrail.RepoClient.originator() do
      belongs_to(
        PaperTrail.RepoClient.originator()[:name],
        PaperTrail.RepoClient.originator()[:model],
        define_field: false,
        foreign_key: :originator_id,
        type: @originator_type
      )
    end

    timestamps(updated_at: false)
  end

  def changeset(model, params \\ %{}) do
    model
    |> cast(params, [:item_type, :item_id, :item_changes, :origin, :originator_id, :meta])
    |> validate_required([:event, :item_type, :item_id, :item_changes])
  end

  @doc """
  Returns the count of all version records in the database
  """
  def count(options \\ []) do
    from(version in __MODULE__, select: count(version.id))
    |> Ecto.Queryable.to_query()
    |> Map.put(:prefix, options[:prefix])
    |> PaperTrail.RepoClient.repo(options).one
  end

  @doc """
  Returns the first version record in the database by :inserted_at
  """
  def first(options \\ []) do
    from(record in __MODULE__, limit: 1, order_by: [asc: :inserted_at])
    |> Ecto.Queryable.to_query()
    |> Map.put(:prefix, options[:prefix])
    |> PaperTrail.RepoClient.repo(options).one
  end

  @doc """
  Returns the last version record in the database by :inserted_at
  """
  def last(options \\ []) do
    from(record in __MODULE__, limit: 1, order_by: [desc: :inserted_at])
    |> Ecto.Queryable.to_query()
    |> Map.put(:prefix, options[:prefix])
    |> PaperTrail.RepoClient.repo(options).one
  end
end
