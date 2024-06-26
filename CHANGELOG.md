### v0.12.0 - June 14th, 2024:
- Fix item_id for composite primary keys

### v0.11.0 - June 11th, 2024:
- Support serialization of list of embeds
- Update Ecto and EctoSql to 3.11.2
- Require Elixir >= 1.15

### v0.10.0 - Augh 7th, 2020:
- Add returning option to update_all

### v0.9.0 - May 14th, 2020:
- Add support for multiple repos
- Add return operation option
- Support update all

### v0.8.3 - September 10th, 2019:
- PaperTrail.delete now accepts Ecto.Changeset

### v0.8.2 - June 29th, 2019:
- Rare PaperTrail.RepoClient.repo compile time errors fixed.

##### ... many changes

### v0.6.0 - March 14th, 2017:
- Version event names are now 'insert', 'update', 'delete' to match their Ecto counterpats instead of 'create', 'update', 'destroy'.
- Introduction of strict mode. Please read the documentation for more information on the required origin and originator_id field and foreign-key references.
