defmodule PaperTrail do
  @moduledoc """
  Provide functions to insert, update and delete records on the database alongside their changes.

  # Usage:

  ```
  defmodule MyApp.PaperTrail do
    use PaperTrail,
      repo: MyApp.Repo,
      originator_type: Ecto.UUID,
      item_type: Ecto.UUID
  end

  defmodule MyApp.Context do
    def create_user(params) do
      changeset = MyApp.User.create_changeset(params)
      # A `PaperTrail.Version` record with event `insert` is inserted
      MyApp.PaperTrail.insert(changeset)
    end

    def update_user(user, params) do
      changeset = MyApp.User.update_changeset(user, params)
      # A `PaperTrail.Version` record with event `update` is inserted
      MyApp.PaperTrail.update(changeset)
    end

    def delete_user(user) do
      # A `PaperTrail.Version` record with event `delete` is inserted
      MyApp.PaperTrail.delete(user)
    end
  end
  """
  import Ecto.Changeset

  alias Ecto.Changeset
  alias PaperTrail.Multi
  alias PaperTrail.RepoClient
  alias PaperTrail.Serializer
  alias PaperTrail.Version
  alias PaperTrail.VersionQueries

  @type repo :: module | nil
  @type strict_mode :: boolean | nil
  @type origin :: String.t() | nil
  @type meta :: map | nil
  @type originator :: Ecto.Schema.t() | nil
  @type prefix :: String.t() | nil
  @type multi_name :: Ecto.Multi.name() | nil
  @type queryable :: Ecto.Queryable.t()
  @type updates :: Keyword.t()

  @type options ::
          []
          | [
              repo: repo,
              strict_mode: strict_mode,
              origin: origin,
              meta: meta,
              originator: originator,
              prefix: prefix,
              model_key: multi_name,
              version_key: multi_name,
              return_operation: multi_name,
              returning: boolean(),
              repo_options: Keyword.t()
            ]

  @type result :: {:ok, Ecto.Schema.t()} | {:error, Changeset.t()}
  @type all_result :: {integer, nil | [any]}

  @callback insert(Changeset.t(), options) :: result
  @callback insert!(Changeset.t(), options) :: Ecto.Schema.t()
  @callback update(Changeset.t(), options) :: result
  @callback update!(Changeset.t(), options) :: Ecto.Schema.t()
  @callback update_all(queryable, updates, options) :: all_result
  @callback delete(Changeset.t(), options) :: result
  @callback delete!(Changeset.t(), options) :: Ecto.Schema.t()

  @callback get_version(Ecto.Schema.t()) :: Ecto.Query.t()
  @callback get_version(module, any) :: Ecto.Query.t()
  @callback get_version(module, any, keyword) :: Ecto.Query.t()

  @callback get_versions(Ecto.Schema.t()) :: Ecto.Query.t()
  @callback get_versions(module, any) :: Ecto.Query.t()
  @callback get_versions(module, any, keyword) :: Ecto.Query.t()

  @callback get_current_model(Version.t()) :: Ecto.Schema.t()

  defmacro __using__(options \\ []) do
    return_operation_options =
      case Keyword.fetch(options, :return_operation) do
        :error -> []
        {:ok, return_operation} -> [return_operation: return_operation]
      end

    client_options =
      [
        repo: RepoClient.repo(options),
        strict_mode: RepoClient.strict_mode(options)
      ] ++ return_operation_options

    quote do
      @behaviour PaperTrail

      @impl true
      def insert(changeset, options \\ []) when is_list(options) do
        PaperTrail.insert(changeset, merge_options(options))
      end

      @impl true
      def insert!(changeset, options \\ []) when is_list(options) do
        PaperTrail.insert!(changeset, merge_options(options))
      end

      @impl true
      def update(changeset, options \\ []) when is_list(options) do
        PaperTrail.update(changeset, merge_options(options))
      end

      @impl true
      def update!(changeset, options \\ []) when is_list(options) do
        PaperTrail.update!(changeset, merge_options(options))
      end

      @impl true
      def update_all(queryable, updates, options \\ []) when is_list(options) do
        PaperTrail.update_all(queryable, updates, merge_options(options))
      end

      @impl true
      def delete(struct, options \\ []) when is_list(options) do
        PaperTrail.delete(struct, merge_options(options))
      end

      @impl true
      def delete!(struct, options \\ []) when is_list(options) do
        PaperTrail.delete!(struct, merge_options(options))
      end

      @impl true
      def get_version(record) do
        VersionQueries.get_version(record, unquote(client_options))
      end

      @impl true
      def get_version(model_or_record, options) when is_list(options) do
        VersionQueries.get_version(model_or_record, merge_options(options))
      end

      @impl true
      def get_version(model_or_record, id) do
        VersionQueries.get_version(model_or_record, id, unquote(client_options))
      end

      @impl true
      def get_version(model, id, options) when is_list(options) do
        VersionQueries.get_version(model, id, merge_options(options))
      end

      @impl true
      def get_versions(record) do
        VersionQueries.get_versions(record, unquote(client_options))
      end

      @impl true
      def get_versions(model_or_record, options) when is_list(options) do
        VersionQueries.get_versions(model_or_record, merge_options(options))
      end

      @impl true
      def get_versions(model_or_record, id) do
        VersionQueries.get_versions(model_or_record, id, unquote(client_options))
      end

      @impl true
      def get_versions(model, id, options) when is_list(options) do
        VersionQueries.get_versions(model, id, merge_options(options))
      end

      @impl true
      def get_current_model(version) do
        VersionQueries.get_current_model(version, unquote(client_options))
      end

      @spec merge_options(keyword) :: keyword
      def merge_options(options), do: Keyword.merge(unquote(client_options), options)
    end
  end

  defdelegate get_version(record), to: VersionQueries
  defdelegate get_version(model_or_record, id_or_options), to: VersionQueries
  defdelegate get_version(model, id, options), to: VersionQueries
  defdelegate get_versions(record), to: VersionQueries
  defdelegate get_versions(model_or_record, id_or_options), to: VersionQueries
  defdelegate get_versions(model, id, options), to: VersionQueries
  defdelegate get_current_model(version, options \\ []), to: VersionQueries
  defdelegate make_version_struct(version, model, options), to: Serializer
  defdelegate get_sequence_from_model(changeset, options \\ []), to: Serializer
  defdelegate serialize(data, options), to: Serializer
  defdelegate get_sequence_id(table_name, options \\ []), to: Serializer
  defdelegate add_prefix(changeset, prefix), to: Serializer
  defdelegate get_item_type(data), to: Serializer
  defdelegate get_model_id(model), to: Serializer

  @doc """
  Inserts a record to the database with a related version insertion in one transaction
  """
  @spec insert(Changeset.t(), options) :: result
  def insert(changeset, options \\ []) do
    Multi.new()
    |> Multi.insert(changeset, options)
    |> Multi.commit(options)
  end

  @doc """
  Same as insert/2 but returns only the model struct or raises if the changeset is invalid.
  """
  @spec insert!(Ecto.Schema.t(), options) :: Ecto.Schema.t()
  def insert!(changeset, options \\ []) do
    repo = RepoClient.repo(options)
    repo_options = Keyword.get(options, :repo_options, [])

    fn ->
      if RepoClient.strict_mode(options) do
        version_id = get_sequence_id("versions", options) + 1

        changeset_data =
          changeset
          |> Map.get(:data, changeset)
          |> Map.merge(%{
            id: get_sequence_from_model(changeset, options) + 1,
            first_version_id: version_id,
            current_version_id: version_id
          })

        initial_version =
          %{event: "insert"}
          |> make_version_struct(changeset_data, options)
          |> repo.insert!

        updated_changeset =
          change(changeset, %{first_version_id: initial_version.id, current_version_id: initial_version.id})

        model = repo.insert!(updated_changeset, repo_options)

        target_version =
          %{event: "insert"} |> make_version_struct(model, options) |> serialize(options)

        initial_version |> Version.changeset(target_version) |> repo.update!
        model
      else
        model = repo.insert!(changeset, repo_options)
        %{event: "insert"} |> make_version_struct(model, options) |> repo.insert!
        model
      end
    end
    |> repo.transaction()
    |> elem(1)
  end

  @doc """
  Updates a record from the database with a related version insertion in one transaction
  """
  @spec update(Changeset.t(), options) :: result
  def update(changeset, options \\ []) do
    Multi.new()
    |> Multi.update(changeset, options)
    |> Multi.commit(options)
  end

  @doc """
  Same as update/2 but returns only the model struct or raises if the changeset is invalid.
  """
  @spec update!(Ecto.Schema.t(), options) :: Ecto.Schema.t()
  def update!(changeset, options \\ []) do
    repo = RepoClient.repo(options)
    repo_options = Keyword.get(options, :repo_options, [])

    fn ->
      if RepoClient.strict_mode(options) do
        version_data =
          Map.merge(changeset.data, %{current_version_id: get_sequence_id("versions", options)})

        target_changeset = Map.merge(changeset, %{data: version_data})
        target_version = make_version_struct(%{event: "update"}, target_changeset, options)
        initial_version = repo.insert!(target_version)
        updated_changeset = change(changeset, %{current_version_id: initial_version.id})
        model = repo.update!(updated_changeset, repo_options)

        new_item_changes =
          Map.merge(initial_version.item_changes, %{current_version_id: initial_version.id})

        initial_version |> change(%{item_changes: new_item_changes}) |> repo.update!
        model
      else
        model = repo.update!(changeset, repo_options)
        version_struct = make_version_struct(%{event: "update"}, changeset, options)
        repo.insert!(version_struct)
        model
      end
    end
    |> repo.transaction()
    |> elem(1)
  end

  @doc """
  Updates all records from the database with a related version insertion in one transaction
  """
  @spec update_all(queryable, updates, options) :: all_result
  def update_all(queryable, updates, options \\ []) do
    Multi.new()
    |> Multi.update_all(queryable, updates, options)
    |> Multi.commit(options)
    |> elem(1)
  end

  @doc """
  Deletes a record from the database with a related version insertion in one transaction
  """
  @spec delete(Changeset.t(), options) :: result
  def delete(struct, options \\ []) do
    Multi.new()
    |> Multi.delete(struct, options)
    |> Multi.commit(options)
  end

  @doc """
  Same as delete/2 but returns only the model struct or raises if the changeset is invalid.
  """
  @spec delete!(Ecto.Schema.t(), options) :: Ecto.Schema.t()
  def delete!(struct, options \\ []) do
    repo = RepoClient.repo(options)
    repo_options = Keyword.get(options, :repo_options, [])

    fn ->
      model = repo.delete!(struct, repo_options)
      version_struct = make_version_struct(%{event: "delete"}, struct, options)
      repo.insert!(version_struct, options)
      model
    end
    |> repo.transaction()
    |> elem(1)
  end
end
