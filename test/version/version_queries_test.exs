defmodule PaperTrailTest.VersionQueries do
  @moduledoc false
  use ExUnit.Case, async: false

  import Ecto.Query

  alias PaperTrail.RepoClient
  alias PaperTrail.Version
  alias PaperTrailTest.MultiTenantHelper, as: MultiTenant
  alias SimpleCompany, as: Company
  alias SimplePerson, as: Person

  defdelegate repo, to: RepoClient

  defmodule CustomPaperTrail do
    @moduledoc false
    use PaperTrail,
      repo: PaperTrail.Repo,
      strict_mode: false,
      originator_type: :integer
  end

  setup_all do
    MultiTenant.setup_tenant(repo())
    reset_all_data()

    %Company{}
    |> Company.changeset(%{
      name: "Acme LLC",
      is_active: true,
      city: "Greenwich"
    })
    |> CustomPaperTrail.insert()

    old_company = Company |> first(:id) |> repo().one

    old_company
    |> Company.changeset(%{
      city: "Hong Kong",
      website: "http://www.acme.com",
      facebook: "acme.llc"
    })
    |> CustomPaperTrail.update()

    Company |> first(:id) |> repo().one |> CustomPaperTrail.delete()

    %Company{}
    |> Company.changeset(%{
      name: "Acme LLC",
      website: "http://www.acme.com"
    })
    |> CustomPaperTrail.insert()

    %Company{}
    |> Company.changeset(%{
      name: "Another Company Corp.",
      is_active: true,
      address: "Sesame street 100/3, 101010"
    })
    |> CustomPaperTrail.insert()

    company = Company |> first(:id) |> repo().one

    # add link name later on
    %Person{}
    |> Person.changeset(%{
      first_name: "Izel",
      last_name: "Nakri",
      gender: true,
      company_id: company.id
    })
    |> CustomPaperTrail.insert(set_by: "admin")

    another_company =
      repo().one(
        from(
          c in Company,
          where: c.name == "Another Company Corp.",
          limit: 1
        )
      )

    Person
    |> first(:id)
    |> repo().one
    |> Person.changeset(%{
      first_name: "Isaac",
      visit_count: 10,
      birthdate: ~D[1992-04-01],
      company_id: another_company.id
    })
    |> CustomPaperTrail.update(set_by: "user:1", meta: %{linkname: "izelnakri"})

    # Multi tenant
    %Company{}
    |> Company.changeset(%{
      name: "Acme LLC",
      is_active: true,
      city: "Greenwich"
    })
    |> MultiTenant.add_prefix_to_changeset()
    |> CustomPaperTrail.insert(prefix: MultiTenant.tenant())

    company_multi =
      Company
      |> first(:id)
      |> MultiTenant.add_prefix_to_query()
      |> repo().one

    %Person{}
    |> Person.changeset(%{
      first_name: "Izel",
      last_name: "Nakri",
      gender: true,
      company_id: company_multi.id
    })
    |> MultiTenant.add_prefix_to_changeset()
    |> CustomPaperTrail.insert(set_by: "admin", prefix: MultiTenant.tenant())

    :ok
  end

  test "get_version gives us the right version" do
    tenant = MultiTenant.tenant()
    last_person = Person |> last(:id) |> repo().one
    target_version = Version |> last(:id) |> repo().one

    last_person_multi =
      Person
      |> last(:id)
      |> MultiTenant.add_prefix_to_query()
      |> repo().one

    target_version_multi =
      Version
      |> last(:id)
      |> MultiTenant.add_prefix_to_query()
      |> repo().one

    assert CustomPaperTrail.get_version(last_person) == target_version
    assert CustomPaperTrail.get_version(Person, last_person.id) == target_version
    assert CustomPaperTrail.get_version(last_person_multi, prefix: tenant) == target_version_multi

    assert CustomPaperTrail.get_version(Person, last_person_multi.id, prefix: tenant) ==
             target_version_multi

    assert target_version != target_version_multi
  end

  test "get_versions gives us the right versions" do
    tenant = MultiTenant.tenant()
    last_person = Person |> last(:id) |> repo().one

    target_versions =
      repo().all(
        from(
          version in Version,
          where: version.item_type == "SimplePerson" and version.item_id == ^last_person.id
        )
      )

    last_person_multi =
      Person
      |> last(:id)
      |> MultiTenant.add_prefix_to_query()
      |> repo().one

    target_versions_multi =
      from(
        version in Version,
        where: version.item_type == "SimplePerson" and version.item_id == ^last_person_multi.id
      )
      |> MultiTenant.add_prefix_to_query()
      |> repo().all

    assert CustomPaperTrail.get_versions(last_person) == target_versions
    assert CustomPaperTrail.get_versions(Person, last_person.id) == target_versions

    assert CustomPaperTrail.get_versions(last_person_multi, prefix: tenant) ==
             target_versions_multi

    assert CustomPaperTrail.get_versions(Person, last_person_multi.id, prefix: tenant) ==
             target_versions_multi

    assert target_versions != target_versions_multi
  end

  test "get_current_model/1 gives us the current record of a version" do
    person = Person |> first(:id) |> repo().one

    first_version =
      Version
      |> where([v], v.item_type == "SimplePerson" and v.item_id == ^person.id)
      |> first()
      |> repo().one

    assert CustomPaperTrail.get_current_model(first_version) == person
  end

  # query meta data!!

  # Functions
  defp reset_all_data do
    repo().delete_all(Person)
    repo().delete_all(Company)
    repo().delete_all(Version)

    Person
    |> MultiTenant.add_prefix_to_query()
    |> repo().delete_all()

    Company
    |> MultiTenant.add_prefix_to_query()
    |> repo().delete_all()

    Version
    |> MultiTenant.add_prefix_to_query()
    |> repo().delete_all()
  end
end
