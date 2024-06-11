defmodule PaperTrail.VersionQueries do
  @moduledoc false
  import Ecto.Query

  alias PaperTrail.Version

  @doc """
  Gets all the versions of a record.
  """
  @spec get_versions(record :: Ecto.Schema.t()) :: Ecto.Query.t()
  def get_versions(record), do: get_versions(record, [])

  @doc """
  Gets all the versions of a record.

  A list of options is optional, so you can set for example the :prefix of the query,
  wich allows you to change between different tenants.

  # Usage example:

    iex(1)> PaperTrail.VersionQueries.get_versions(record, [prefix: "tenant_id"])
  """
  @spec get_versions(module | Ecto.Schema.t(), any | keyword) :: Ecto.Query.t()
  def get_versions(model, id) when is_atom(model) and not is_list(id), do: get_versions(model, id, [])

  def get_versions(record, options) when is_map(record) and is_list(options) do
    item_type = record.__struct__ |> Module.split() |> List.last()

    item_type
    |> version_query(PaperTrail.get_model_id(record), options)
    |> PaperTrail.RepoClient.repo(options).all
  end

  @doc """
  Gets all the versions of a record given a module and its id.

  A list of options is optional, so you can set for example the :prefix of the query,
  wich allows you to change between different tenants.

  # Usage example:

    iex(1)> PaperTrail.VersionQueries.get_versions(ModelName, id, [prefix: "tenant_id"])
  """
  @spec get_versions(model :: module, id :: any, options :: keyword) :: Ecto.Query.t()
  def get_versions(model, id, options) do
    item_type = model |> Module.split() |> List.last()
    item_type |> version_query(id, options) |> PaperTrail.RepoClient.repo(options).all
  end

  @doc """
  Gets the last version of a record.
  """
  @spec get_version(record :: Ecto.Schema.t()) :: Ecto.Query.t()
  def get_version(record), do: get_version(record, [])

  @doc """
  Gets the last version of a record.


  A list of options is optional, so you can set for example the :prefix of the query,
  wich allows you to change between different tenants.

  # Usage example:

    iex(1)> PaperTrail.VersionQueries.get_version(record, [prefix: "tenant_id"])
  """
  @spec get_version(module | Ecto.Schema.t(), any | keyword) :: Ecto.Query.t()
  def get_version(model, id) when is_atom(model) and not is_list(id), do: get_version(model, id, [])

  def get_version(record, options) when is_map(record) do
    item_type = record.__struct__ |> Module.split() |> List.last()

    item_type
    |> version_query(PaperTrail.get_model_id(record), options)
    |> last()
    |> PaperTrail.RepoClient.repo(options).one
  end

  @doc """
  Gets the last version of a record given its module reference and its id.

  A list of options is optional, so you can set for example the :prefix of the query,
  wich allows you to change between different tenants.

  # Usage example:

    iex(1)> PaperTrail.VersionQueries.get_version(ModelName, id, [prefix: "tenant_id"])
  """
  @spec get_version(model :: module, id :: any, options :: keyword) :: Ecto.Query.t()
  def get_version(model, id, options) do
    item_type = model |> Module.split() |> List.last()
    item_type |> version_query(id, options) |> last() |> PaperTrail.RepoClient.repo(options).one
  end

  @doc """
  Gets the current model record/struct of a version
  """
  def get_current_model(version, options \\ []) do
    PaperTrail.RepoClient.repo(options).get(
      String.to_existing_atom("Elixir." <> version.item_type),
      version.item_id
    )
  end

  defp version_query(item_type, id) do
    from(v in Version, where: v.item_type == ^item_type and v.item_id == ^id)
  end

  defp version_query(item_type, id, options) do
    with opts <- Map.new(options) do
      item_type
      |> version_query(id)
      |> Ecto.Queryable.to_query()
      |> Map.merge(opts)
    end
  end
end
