defmodule PaperTrailTest.StrictModeBangFunctions do
  @moduledoc false
  use ExUnit.Case, async: false

  import Ecto.Query

  alias PaperTrail.RepoClient
  alias PaperTrail.Serializer
  alias PaperTrail.Version
  alias PaperTrailTest.MultiTenantHelper, as: MultiTenant
  alias StrictCompany, as: Company
  alias StrictPerson, as: Person

  @create_company_params %{name: "Acme LLC", is_active: true, city: "Greenwich"}
  @update_company_params %{
    city: "Hong Kong",
    website: "http://www.acme.com",
    facebook: "acme.llc"
  }

  defdelegate repo, to: RepoClient

  doctest PaperTrail

  defmodule CustomPaperTrail do
    @moduledoc false
    use PaperTrail,
      repo: PaperTrail.Repo,
      strict_mode: true,
      originator_type: :integer
  end

  setup_all do
    all_env = Application.get_all_env(:paper_trail)

    Application.put_env(:paper_trail, :strict_mode, true)
    Application.put_env(:paper_trail, :repo, PaperTrail.Repo)
    Application.put_env(:paper_trail, :originator_type, :integer)

    on_exit(fn ->
      Application.put_all_env(paper_trail: all_env)
    end)

    MultiTenant.setup_tenant(repo())
    :ok
  end

  setup do
    reset_all_data()

    on_exit(fn ->
      reset_all_data()
    end)

    :ok
  end

  test "creating a company creates a company version with correct attributes" do
    user = create_user()
    inserted_company = create_company_with_version(@create_company_params, user: user)

    company_count = Company.count()
    version_count = Version.count()

    company = serialize(inserted_company)
    version = inserted_company |> CustomPaperTrail.get_version() |> serialize()

    assert company_count == 1
    assert version_count == 1

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Greenwich",
             website: nil,
             address: nil,
             facebook: nil,
             twitter: nil,
             founded_in: nil,
             first_version_id: version.id,
             current_version_id: version.id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "StrictCompany",
             item_id: company.id,
             item_changes: convert_to_string_map(company),
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == Company |> first(:id) |> repo().one |> serialize()
  end

  test "creating a company without changeset creates a company version with correct attributes" do
    inserted_company = CustomPaperTrail.insert!(%Company{name: "Acme LLC"})
    company_count = Company.count()
    version_count = Version.count()

    company = serialize(inserted_company)
    version = inserted_company |> CustomPaperTrail.get_version() |> serialize()

    assert company_count == 1
    assert version_count == 1

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: nil,
             city: nil,
             website: nil,
             address: nil,
             facebook: nil,
             twitter: nil,
             founded_in: nil,
             first_version_id: version.id,
             current_version_id: version.id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "StrictCompany",
             item_id: company.id,
             item_changes: convert_to_string_map(company),
             originator_id: nil,
             origin: nil,
             meta: nil
           }
  end

  test "CustomPaperTrail.insert!/2 with an error raises Ecto.InvalidChangesetError" do
    assert_raise(Ecto.InvalidChangesetError, fn ->
      create_company_with_version(%{name: nil, is_active: true, city: "Greenwich"})
    end)
  end

  test "updating a company creates a company version with correct item_changes" do
    user = create_user()
    inserted_company = create_company_with_version()
    inserted_company_version = inserted_company |> CustomPaperTrail.get_version() |> serialize()

    updated_company =
      update_company_with_version(
        inserted_company,
        @update_company_params,
        originator: user
      )

    company_count = Company.count()
    version_count = Version.count()

    company = serialize(updated_company)
    updated_company_version = updated_company |> CustomPaperTrail.get_version() |> serialize()

    assert company_count == 1
    assert version_count == 2

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil,
             first_version_id: inserted_company_version.id,
             current_version_id: updated_company_version.id
           }

    assert Map.drop(updated_company_version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "StrictCompany",
             item_id: company.id,
             item_changes:
               convert_to_string_map(%{
                 city: "Hong Kong",
                 website: "http://www.acme.com",
                 facebook: "acme.llc",
                 current_version_id: updated_company_version.id
               }),
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == Company |> first(:id) |> repo().one |> serialize()
  end

  test "CustomPaperTrail.update!/2 with an error raises Ecto.InvalidChangesetError" do
    assert_raise(Ecto.InvalidChangesetError, fn ->
      inserted_company = create_company_with_version()

      update_company_with_version(inserted_company, %{
        name: nil,
        city: "Hong Kong",
        website: "http://www.acme.com",
        facebook: "acme.llc"
      })
    end)
  end

  test "deleting a company creates a company version with correct attributes" do
    user = create_user()
    inserted_company = create_company_with_version()
    inserted_company_version = CustomPaperTrail.get_version(inserted_company)
    updated_company = update_company_with_version(inserted_company)
    updated_company_version = CustomPaperTrail.get_version(updated_company)
    company_before_deletion = Company |> first(:id) |> repo().one |> serialize()
    deleted_company = CustomPaperTrail.delete!(updated_company, user: user)

    company_count = Company.count()
    version_count = Version.count()

    old_company = serialize(deleted_company)
    deleted_company_version = deleted_company |> CustomPaperTrail.get_version() |> serialize()

    assert company_count == 0
    assert version_count == 3

    assert Map.drop(old_company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil,
             first_version_id: inserted_company_version.id,
             current_version_id: updated_company_version.id
           }

    assert Map.drop(deleted_company_version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "StrictCompany",
             item_id: old_company.id,
             item_changes:
               convert_to_string_map(%{
                 id: old_company.id,
                 inserted_at: old_company.inserted_at,
                 updated_at: old_company.updated_at,
                 name: "Acme LLC",
                 is_active: true,
                 website: "http://www.acme.com",
                 city: "Hong Kong",
                 address: nil,
                 facebook: "acme.llc",
                 twitter: nil,
                 founded_in: nil,
                 first_version_id: inserted_company_version.id,
                 current_version_id: updated_company_version.id
               }),
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert old_company == company_before_deletion
  end

  test "CustomPaperTrail.delete!/2 with an error raises Ecto.InvalidChangesetError" do
    assert_raise(Ecto.InvalidChangesetError, fn ->
      inserted_company = create_company_with_version()

      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_company.id
      })
      |> CustomPaperTrail.insert!()

      inserted_company |> Company.changeset() |> CustomPaperTrail.delete!()
    end)
  end

  test "creating a person with meta tag creates a person version with correct attributes" do
    create_company_with_version(%{name: "Acme LLC", website: "http://www.acme.com"})

    inserted_company =
      create_company_with_version(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    inserted_person =
      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_company.id
      })
      |> CustomPaperTrail.insert!(origin: "admin", meta: %{linkname: "izelnakri"})

    person_count = Person.count()
    version_count = Version.count()

    person = serialize(inserted_person)
    version = inserted_person |> CustomPaperTrail.get_version() |> serialize()

    assert person_count == 1
    assert version_count == 3

    assert Map.drop(person, [:id, :inserted_at, :updated_at]) == %{
             first_name: "Izel",
             last_name: "Nakri",
             gender: true,
             visit_count: nil,
             birthdate: nil,
             company_id: inserted_company.id,
             first_version_id: version.id,
             current_version_id: version.id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "StrictPerson",
             item_id: person.id,
             item_changes: convert_to_string_map(person),
             originator_id: nil,
             origin: "admin",
             meta: %{"linkname" => "izelnakri"}
           }

    assert person == Person |> first(:id) |> repo().one |> serialize()
  end

  test "updating a person creates a person version with correct attributes" do
    inserted_initial_company =
      create_company_with_version(%{
        name: "Acme LLC",
        website: "http://www.acme.com"
      })

    inserted_target_company =
      create_company_with_version(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    inserted_person =
      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_target_company.id
      })
      |> CustomPaperTrail.insert!(origin: "admin")

    inserted_person_version = inserted_person |> CustomPaperTrail.get_version() |> serialize()

    updated_person =
      inserted_person
      |> Person.changeset(%{
        first_name: "Isaac",
        visit_count: 10,
        birthdate: ~D[1992-04-01],
        company_id: inserted_initial_company.id
      })
      |> CustomPaperTrail.update!(origin: "scraper", meta: %{linkname: "izelnakri"})

    person_count = Person.count()
    company_count = Company.count()
    version_count = Version.count()

    person = serialize(updated_person)
    updated_person_version = updated_person |> CustomPaperTrail.get_version() |> serialize()

    assert person_count == 1
    assert company_count == 2
    assert version_count == 4

    assert Map.drop(person, [:id, :inserted_at, :updated_at]) == %{
             company_id: inserted_initial_company.id,
             first_name: "Isaac",
             visit_count: 10,
             #  this is the only problem
             birthdate: ~D[1992-04-01],
             last_name: "Nakri",
             gender: true,
             first_version_id: inserted_person_version.id,
             current_version_id: updated_person_version.id
           }

    assert Map.drop(updated_person_version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "StrictPerson",
             item_id: person.id,
             item_changes:
               convert_to_string_map(%{
                 first_name: "Isaac",
                 visit_count: 10,
                 birthdate: ~D[1992-04-01],
                 current_version_id: updated_person_version.id,
                 company_id: inserted_initial_company.id
               }),
             originator_id: nil,
             origin: "scraper",
             meta: %{"linkname" => "izelnakri"}
           }

    assert person == Person |> first(:id) |> repo().one |> serialize()
  end

  test "deleting a person creates a person version with correct attributes" do
    create_company_with_version(%{name: "Acme LLC", website: "http://www.acme.com"})

    inserted_company =
      create_company_with_version(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    inserted_person =
      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_company.id
      })
      |> CustomPaperTrail.insert!(origin: "admin")

    inserted_person_version = inserted_person |> CustomPaperTrail.get_version() |> serialize()

    updated_person =
      inserted_person
      |> Person.changeset(%{
        first_name: "Isaac",
        visit_count: 10,
        birthdate: ~D[1992-04-01]
      })
      |> CustomPaperTrail.update!(origin: "scraper", meta: %{linkname: "izelnakri"})

    updated_person_version = updated_person |> CustomPaperTrail.get_version() |> serialize()
    person_before_deletion = Person |> first(:id) |> repo().one

    deleted_person =
      CustomPaperTrail.delete!(
        updated_person,
        origin: "admin",
        meta: %{linkname: "izelnakri"}
      )

    deleted_person_version = deleted_person |> CustomPaperTrail.get_version() |> serialize()

    person_count = Person.count()
    company_count = Company.count()
    version_count = Version.count()

    assert person_count == 0
    assert company_count == 2
    assert version_count == 5

    assert Map.drop(deleted_person_version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "StrictPerson",
             item_id: deleted_person.id,
             item_changes:
               convert_to_string_map(%{
                 id: deleted_person.id,
                 inserted_at: deleted_person.inserted_at,
                 updated_at: deleted_person.updated_at,
                 first_name: "Isaac",
                 last_name: "Nakri",
                 gender: true,
                 visit_count: 10,
                 birthdate: ~D[1992-04-01],
                 company_id: inserted_company.id,
                 first_version_id: inserted_person_version.id,
                 current_version_id: updated_person_version.id
               }),
             originator_id: nil,
             origin: "admin",
             meta: %{"linkname" => "izelnakri"}
           }

    assert serialize(deleted_person) == serialize(person_before_deletion)
  end

  # Multi tenant tests
  test "[multi tenant] creating a company creates a company version with correct attributes" do
    tenant = MultiTenant.tenant()
    user = create_user(:multitenant)
    inserted_company = create_company_with_version_multi(@create_company_params, user: user)

    company_count = Company.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    company = serialize(inserted_company)

    version =
      inserted_company
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    assert Company.count() == 0
    assert Version.count() == 0
    assert company_count == 1
    assert version_count == 1

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Greenwich",
             website: nil,
             address: nil,
             facebook: nil,
             twitter: nil,
             founded_in: nil,
             first_version_id: version.id,
             current_version_id: version.id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "StrictCompany",
             item_id: company.id,
             item_changes: convert_to_string_map(company),
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == :multitenant |> first_company() |> serialize()
  end

  test "[multi tenant] creating a company without changeset creates a company version with correct attributes" do
    tenant = MultiTenant.tenant()

    inserted_company =
      create_company_with_version_multi(%{name: "Acme LLC"}, prefix: MultiTenant.tenant())

    company_count = Company.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    company = serialize(inserted_company)

    version =
      inserted_company
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    assert Company.count() == 0
    assert Version.count() == 0
    assert company_count == 1
    assert version_count == 1

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: nil,
             city: nil,
             website: nil,
             address: nil,
             facebook: nil,
             twitter: nil,
             founded_in: nil,
             first_version_id: version.id,
             current_version_id: version.id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "StrictCompany",
             item_id: company.id,
             item_changes: convert_to_string_map(company),
             originator_id: nil,
             origin: nil,
             meta: nil
           }
  end

  test "[multi tenant] CustomPaperTrail.insert!/2 with an error raises Ecto.InvalidChangesetError" do
    assert_raise(Ecto.InvalidChangesetError, fn ->
      create_company_with_version_multi(%{name: nil, is_active: true, city: "Greenwich"})
    end)
  end

  test "[multi tenant] updating a company creates a company version with correct item_changes" do
    tenant = MultiTenant.tenant()

    user = create_user(:multitenant)
    inserted_company = create_company_with_version_multi()

    inserted_company_version =
      inserted_company
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    updated_company =
      update_company_with_version_multi(
        inserted_company,
        @update_company_params,
        originator: user
      )

    company_count = Company.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    company = serialize(updated_company)

    updated_company_version =
      updated_company
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    assert Company.count() == 0
    assert Version.count() == 0
    assert company_count == 1
    assert version_count == 2

    assert Map.drop(company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil,
             first_version_id: inserted_company_version.id,
             current_version_id: updated_company_version.id
           }

    assert Map.drop(updated_company_version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "StrictCompany",
             item_id: company.id,
             item_changes:
               convert_to_string_map(%{
                 city: "Hong Kong",
                 website: "http://www.acme.com",
                 facebook: "acme.llc",
                 current_version_id: updated_company_version.id
               }),
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert company == :multitenant |> first_company() |> serialize()
  end

  test "[multi tenant] CustomPaperTrail.update!/2 with an error raises Ecto.InvalidChangesetError" do
    assert_raise(Ecto.InvalidChangesetError, fn ->
      inserted_company = create_company_with_version_multi()

      update_company_with_version_multi(inserted_company, %{
        name: nil,
        city: "Hong Kong",
        website: "http://www.acme.com",
        facebook: "acme.llc"
      })
    end)
  end

  test "[multi tenant] deleting a company creates a company version with correct attributes" do
    tenant = MultiTenant.tenant()

    user = create_user(:multitenant)
    inserted_company = create_company_with_version_multi()
    inserted_company_version = CustomPaperTrail.get_version(inserted_company, prefix: tenant)
    updated_company = update_company_with_version_multi(inserted_company)
    updated_company_version = CustomPaperTrail.get_version(updated_company, prefix: tenant)
    company_before_deletion = :multitenant |> first_company() |> serialize()
    deleted_company = CustomPaperTrail.delete!(updated_company, user: user, prefix: tenant)

    company_count = Company.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    old_company = serialize(deleted_company)

    deleted_company_version =
      deleted_company
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    assert Company.count() == 0
    assert Version.count() == 0
    assert company_count == 0
    assert version_count == 3

    assert Map.drop(old_company, [:id, :inserted_at, :updated_at]) == %{
             name: "Acme LLC",
             is_active: true,
             city: "Hong Kong",
             website: "http://www.acme.com",
             address: nil,
             facebook: "acme.llc",
             twitter: nil,
             founded_in: nil,
             first_version_id: inserted_company_version.id,
             current_version_id: updated_company_version.id
           }

    assert Map.drop(deleted_company_version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "StrictCompany",
             item_id: old_company.id,
             item_changes:
               convert_to_string_map(%{
                 id: old_company.id,
                 inserted_at: old_company.inserted_at,
                 updated_at: old_company.updated_at,
                 name: "Acme LLC",
                 is_active: true,
                 website: "http://www.acme.com",
                 city: "Hong Kong",
                 address: nil,
                 facebook: "acme.llc",
                 twitter: nil,
                 founded_in: nil,
                 first_version_id: inserted_company_version.id,
                 current_version_id: updated_company_version.id
               }),
             originator_id: user.id,
             origin: nil,
             meta: nil
           }

    assert old_company == company_before_deletion
  end

  test "[multi tenant] CustomPaperTrail.delete!/2 with an error raises Ecto.InvalidChangesetError" do
    tenant = MultiTenant.tenant()

    assert_raise(Ecto.InvalidChangesetError, fn ->
      inserted_company = create_company_with_version_multi()

      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_company.id
      })
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.insert!(prefix: tenant)

      inserted_company
      |> Company.changeset()
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.delete!(prefix: tenant)
    end)
  end

  test "[multi tenant] creating a person with meta tag creates a person version with correct attributes" do
    tenant = MultiTenant.tenant()

    create_company_with_version_multi(%{name: "Acme LLC", website: "http://www.acme.com"})

    inserted_company =
      create_company_with_version_multi(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    inserted_person =
      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_company.id
      })
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.insert!(origin: "admin", meta: %{linkname: "izelnakri"}, prefix: tenant)

    person_count = Person.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    person = serialize(inserted_person)
    version = inserted_person |> CustomPaperTrail.get_version(prefix: tenant) |> serialize()

    assert Person.count() == 0
    assert Version.count() == 0
    assert person_count == 1
    assert version_count == 3

    assert Map.drop(person, [:id, :inserted_at, :updated_at]) == %{
             first_name: "Izel",
             last_name: "Nakri",
             gender: true,
             visit_count: nil,
             birthdate: nil,
             company_id: inserted_company.id,
             first_version_id: version.id,
             current_version_id: version.id
           }

    assert Map.drop(version, [:id, :inserted_at]) == %{
             event: "insert",
             item_type: "StrictPerson",
             item_id: person.id,
             item_changes: convert_to_string_map(person),
             originator_id: nil,
             origin: "admin",
             meta: %{"linkname" => "izelnakri"}
           }

    assert person == :multitenant |> first_person() |> serialize()
  end

  test "[multi tenant] updating a person creates a person version with correct attributes" do
    tenant = MultiTenant.tenant()

    inserted_initial_company =
      create_company_with_version_multi(%{
        name: "Acme LLC",
        website: "http://www.acme.com"
      })

    inserted_target_company =
      create_company_with_version_multi(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    inserted_person =
      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_target_company.id
      })
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.insert!(origin: "admin", prefix: tenant)

    inserted_person_version =
      inserted_person
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    updated_person =
      inserted_person
      |> Person.changeset(%{
        first_name: "Isaac",
        visit_count: 10,
        birthdate: ~D[1992-04-01],
        company_id: inserted_initial_company.id
      })
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.update!(origin: "scraper", meta: %{linkname: "izelnakri"}, prefix: tenant)

    person_count = Person.count(:multitenant)
    company_count = Company.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    person = serialize(updated_person)

    updated_person_version =
      updated_person
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    assert Person.count() == 0
    assert Version.count() == 0
    assert person_count == 1
    assert company_count == 2
    assert version_count == 4

    assert Map.drop(person, [:id, :inserted_at, :updated_at]) == %{
             company_id: inserted_initial_company.id,
             first_name: "Isaac",
             visit_count: 10,
             #  this is the only problem
             birthdate: ~D[1992-04-01],
             last_name: "Nakri",
             gender: true,
             first_version_id: inserted_person_version.id,
             current_version_id: updated_person_version.id
           }

    assert Map.drop(updated_person_version, [:id, :inserted_at]) == %{
             event: "update",
             item_type: "StrictPerson",
             item_id: person.id,
             item_changes:
               convert_to_string_map(%{
                 first_name: "Isaac",
                 visit_count: 10,
                 birthdate: ~D[1992-04-01],
                 current_version_id: updated_person_version.id,
                 company_id: inserted_initial_company.id
               }),
             originator_id: nil,
             origin: "scraper",
             meta: %{"linkname" => "izelnakri"}
           }

    assert person == :multitenant |> first_person() |> serialize()
  end

  test "[multi tenant] deleting a person creates a person version with correct attributes" do
    tenant = MultiTenant.tenant()

    create_company_with_version_multi(%{name: "Acme LLC", website: "http://www.acme.com"})

    inserted_company =
      create_company_with_version_multi(%{
        name: "Another Company Corp.",
        is_active: true,
        address: "Sesame street 100/3, 101010"
      })

    inserted_person =
      %Person{}
      |> Person.changeset(%{
        first_name: "Izel",
        last_name: "Nakri",
        gender: true,
        company_id: inserted_company.id
      })
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.insert!(origin: "admin", prefix: tenant)

    inserted_person_version =
      inserted_person
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    updated_person =
      inserted_person
      |> Person.changeset(%{
        first_name: "Isaac",
        visit_count: 10,
        birthdate: ~D[1992-04-01]
      })
      |> MultiTenant.add_prefix_to_changeset()
      |> CustomPaperTrail.update!(origin: "scraper", meta: %{linkname: "izelnakri"}, prefix: tenant)

    updated_person_version =
      updated_person
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    person_before_deletion = first_person(:multitenant)

    deleted_person =
      CustomPaperTrail.delete!(
        updated_person,
        origin: "admin",
        meta: %{linkname: "izelnakri"},
        prefix: tenant
      )

    deleted_person_version =
      deleted_person
      |> CustomPaperTrail.get_version(prefix: tenant)
      |> serialize()

    person_count = Person.count(:multitenant)
    company_count = Company.count(:multitenant)
    version_count = Version.count(prefix: tenant)

    assert Company.count() == 0
    assert Person.count() == 0
    assert Version.count() == 0
    assert person_count == 0
    assert company_count == 2
    assert version_count == 5

    assert Map.drop(deleted_person_version, [:id, :inserted_at]) == %{
             event: "delete",
             item_type: "StrictPerson",
             item_id: deleted_person.id,
             item_changes:
               convert_to_string_map(%{
                 id: deleted_person.id,
                 inserted_at: deleted_person.inserted_at,
                 updated_at: deleted_person.updated_at,
                 first_name: "Isaac",
                 last_name: "Nakri",
                 gender: true,
                 visit_count: 10,
                 birthdate: ~D[1992-04-01],
                 company_id: inserted_company.id,
                 first_version_id: inserted_person_version.id,
                 current_version_id: updated_person_version.id
               }),
             originator_id: nil,
             origin: "admin",
             meta: %{"linkname" => "izelnakri"}
           }

    assert serialize(deleted_person) == serialize(person_before_deletion)
  end

  # Functions
  defp create_user do
    %User{}
    |> User.changeset(%{token: "fake-token", username: "izelnakri"})
    |> repo().insert!
  end

  defp create_user(:multitenant) do
    %User{}
    |> User.changeset(%{token: "fake-token", username: "izelnakri"})
    |> MultiTenant.add_prefix_to_changeset()
    |> repo().insert!
  end

  defp create_company_with_version(params \\ @create_company_params, options \\ []) do
    %Company{} |> Company.changeset(params) |> CustomPaperTrail.insert!(options)
  end

  defp create_company_with_version_multi(params \\ @create_company_params, options \\ []) do
    opts_with_prefix = Keyword.put(options || [], :prefix, MultiTenant.tenant())

    %Company{}
    |> Company.changeset(params)
    |> MultiTenant.add_prefix_to_changeset()
    |> CustomPaperTrail.insert!(opts_with_prefix)
  end

  defp update_company_with_version(company, params \\ @update_company_params, options \\ []) do
    company |> Company.changeset(params) |> CustomPaperTrail.update!(options)
  end

  defp update_company_with_version_multi(company, params \\ @update_company_params, options \\ []) do
    opts_with_prefix = Keyword.put(options || [], :prefix, MultiTenant.tenant())

    company
    |> Company.changeset(params)
    |> MultiTenant.add_prefix_to_changeset()
    |> CustomPaperTrail.update!(opts_with_prefix)
  end

  defp first_company(:multitenant) do
    Company |> first(:id) |> MultiTenant.add_prefix_to_query() |> repo().one()
  end

  defp first_person(:multitenant) do
    Person |> first(:id) |> MultiTenant.add_prefix_to_query() |> repo().one()
  end

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

  defp convert_to_string_map(map) do
    map |> Jason.encode!() |> Jason.decode!()
  end

  defp serialize(data), do: Serializer.serialize(data, repo: PaperTrail.Repo)
end
