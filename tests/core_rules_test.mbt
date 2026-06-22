///|
test "validates built in rule profiles" {
  let basic = @moon_mutest.validate_rules(
    @moon_mutest.rules_for_profile(BasicProfile),
  )
  inspect(basic.rule_count, content="14")
  inspect(basic.duplicate_labels.length(), content="0")
  inspect(basic.empty_tokens.length(), content="0")

  let boundary = @moon_mutest.validate_rules(
    @moon_mutest.rules_for_profile(BoundaryProfile),
  )
  inspect(boundary.rule_count, content="17")
  inspect(boundary.duplicate_labels.length(), content="0")
}

///|
test "boundary profile discovers numeric literal mutants" {
  let candidates = @moon_mutest.discover_with_profile(
    "let a = 0\nlet b = 1\nlet c = -1\nlet d = 10",
    BoundaryProfile,
  )
  inspect(candidates.length(), content="3")
  inspect(candidates[0].rule.label, content="zero-to-one")
  inspect(candidates[1].rule.label, content="one-to-zero")
  inspect(candidates[2].rule.label, content="minus-one-to-zero")
}

///|
test "formats rule catalog" {
  let text = @moon_mutest.format_rule_catalog(profile=BoundaryProfile)
  assert_true(text.contains("Mutation rule catalog"))
  assert_true(text.contains("zero-to-one"))
  assert_true(text.contains("minus-one-to-zero"))
  assert_true(!text.contains("eq-to-ne"))
}

///|
test "parses rule profile labels" {
  debug_inspect(
    @moon_mutest.parse_rule_profile("basic"),
    content="Some(BasicProfile)",
  )
  debug_inspect(
    @moon_mutest.parse_rule_profile("BoundaryProfile"),
    content="Some(BoundaryProfile)",
  )
  debug_inspect(@moon_mutest.parse_rule_profile("missing"), content="None")
}
