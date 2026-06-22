///|
test "filters candidates by mutation kind" {
  let candidates = @moon_mutest.discover("a + b == c && false")
  let filtered = @moon_mutest.filter_candidates(
    candidates,
    @moon_mutest.MutationFilter::by_kind(EqualityOperator),
  )
  inspect(filtered.length(), content="1")
  inspect(filtered[0].rule.label, content="eq-to-ne")
}

///|
test "filters candidates by label" {
  let filtered = @moon_mutest.discover_filtered(
    "a + b - c",
    @moon_mutest.MutationFilter::by_label("sub-to-add"),
  )
  inspect(filtered.length(), content="1")
  inspect(filtered[0].replacement, content="+")
}

///|
test "filters candidates by inclusive line range" {
  let source =
    #|let a = x + y
    #|let b = x == y
    #|let c = false
    #|
  let filtered = @moon_mutest.discover_filtered(
    source,
    @moon_mutest.MutationFilter::lines(start=2, end=3),
  )
  inspect(filtered.length(), content="2")
  inspect(filtered[0].span.line, content="2")
  inspect(filtered[1].span.line, content="3")
}
