///|
test "generates mutated source for every candidate" {
  let mutants = @moon_mutest.generate_mutants("a + b == c", file="sample.mbt")
  inspect(mutants.length(), content="2")
  inspect(mutants[0].source, content="a - b == c")
  inspect(mutants[1].source, content="a + b != c")
}

///|
test "selects mutant by id" {
  match @moon_mutest.mutant_by_id("a && false", 1, file="logic.mbt") {
    Some(mutant) => {
      inspect(mutant.candidate.rule.label, content="false-to-true")
      inspect(mutant.source, content="a && true")
    }
    None => fail("expected mutant")
  }
  assert_true(@moon_mutest.mutant_by_id("a && false", 9) is None)
}

///|
test "formats single line mutant patch" {
  let mutant = @moon_mutest.generate_mutants("a <= b", file="math.mbt")[0]
  inspect(
    @moon_mutest.format_mutant_patch(mutant),
    content=(
      #|mutant #0: le-to-lt
      #|math.mbt:1:3
      #|- a <= b
      #|+ a < b
    ),
  )
}
