defmodule PaperTrailTest.UUIDTest do
  use ExUnit.Case, async: false

  import Ecto.Query
  import PaperTrail.RepoClient, only: [repo: 0]

  alias PaperTrail.Version

  defmodule CustomPaperTrail do
    @moduledoc false
    use PaperTrail,
      repo: PaperTrail.UUIDRepo,
      strict_mode: false,
      originator_type: Ecto.UUID,
      item_type: Ecto.UUID
  end

  setup_all do
    all_env = Application.get_all_env(:paper_trail)

    Application.put_env(:paper_trail, :repo, PaperTrail.UUIDRepo)
    Application.put_env(:paper_trail, :originator, name: :admin, model: Admin)
    Application.put_env(:paper_trail, :originator_type, Ecto.UUID)
    Application.put_env(:paper_trail, :item_type, Ecto.UUID)

    Code.eval_file("lib/version.ex")

    on_exit(fn ->
      Application.put_all_env(paper_trail: all_env)
    end)

    repo().delete_all(Version)
    repo().delete_all(Admin)
    repo().delete_all(Product)
    repo().delete_all(Item)
    :ok
  end

  describe "PaperTrailTest.UUIDTest" do
    test "creates versions with models that have a UUID primary key" do
      product =
        %Product{}
        |> Product.changeset(%{name: "Hair Cream"})
        |> CustomPaperTrail.insert!()

      version = Version |> last() |> repo().one

      assert version.item_id == product.id
      assert version.item_type == "Product"
    end

    test "handles originators with a UUID primary key" do
      admin =
        %Admin{}
        |> Admin.changeset(%{email: "admin@example.com"})
        |> repo().insert!

      %Product{}
      |> Product.changeset(%{name: "Hair Cream"})
      |> CustomPaperTrail.insert!(originator: admin)

      version =
        Version
        |> last()
        |> repo().one
        |> repo().preload(:admin)

      assert version.admin == admin
    end

    test "versioning models that have a non-regular primary key" do
      item =
        %Item{}
        |> Item.changeset(%{title: "hello"})
        |> CustomPaperTrail.insert!()

      version = Version |> last() |> repo().one
      assert version.item_id == item.item_id

      uuid_item =
        %UUIDItem{}
        |> UUIDItem.changeset(%{title: "hello"})
        |> CustomPaperTrail.insert!()

      version = Version |> last() |> repo().one
      assert version.item_id == uuid_item.item_id
    end

    test "test INTEGER primary key for item_type == :string" do
      if PaperTrail.Version.__schema__(:type, :item_id) == :string do
        item =
          %FooItem{}
          |> FooItem.changeset(%{title: "hello"})
          |> CustomPaperTrail.insert!()

        version = Version |> last() |> repo().one
        assert version.item_id == "#{item.id}"
      end
    end

    test "test STRING primary key for item_type == :string" do
      if PaperTrail.Version.__schema__(:type, :item_id) == :string do
        item =
          %BarItem{}
          |> BarItem.changeset(%{item_id: "#{:os.system_time()}", title: "hello"})
          |> CustomPaperTrail.insert!()

        version = Version |> last() |> repo().one
        assert version.item_id == item.item_id
      end
    end
  end
end
