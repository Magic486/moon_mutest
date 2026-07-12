///|
test "equivalent config preserves reviewed mutant reasons" {
  let config : CliRunConfig = @json.from_json(
    @json.parse("{\"equivalent\":[{\"id\":3,\"reason\":\"domain invariant\"}]}"),
  )
  let equivalents = equivalent_mutants(config)
  inspect(equivalents.length(), content="1")
  inspect(equivalents[0].id, content="3")
  inspect(equivalents[0].reason, content="domain invariant")
}
