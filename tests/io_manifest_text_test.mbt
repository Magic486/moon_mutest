///|
test "formats candidate list" {
  let candidates = @moon_mutest.discover("a == b && true", file="sample.mbt")
  inspect(
    @moon_mutest.format_candidate_list(candidates),
    content=(
      #|#0 sample.mbt:1:3 eq-to-ne == -> != | a == b && true
      #|#1 sample.mbt:1:8 and-to-or && -> || | a == b && true
      #|#2 sample.mbt:1:11 true-to-false true -> false | a == b && true
    ),
  )
}

///|
test "formats manifest with summary" {
  inspect(
    @moon_mutest.format_manifest("a + b", file="math.mbt"),
    content=(
      #|Mutation candidates for math.mbt
      #|total: 1
      #|boolean: 0
      #|equality: 0
      #|relational: 0
      #|arithmetic: 1
      #|logical: 0
      #|numeric: 0
      #|
      #|#0 math.mbt:1:3 add-to-sub + -> - | a + b
    ),
  )
}

///|
test "formats manifest with boundary profile" {
  inspect(
    @moon_mutest.format_manifest_with_profile(
      "let n = 0",
      BoundaryProfile,
      file="n.mbt",
    ),
    content=(
      #|Mutation candidates for n.mbt
      #|total: 1
      #|boolean: 0
      #|equality: 0
      #|relational: 0
      #|arithmetic: 0
      #|logical: 0
      #|numeric: 1
      #|
      #|#0 n.mbt:1:9 zero-to-one 0 -> 1 | let n = 0
    ),
  )
}
