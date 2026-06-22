///|
test "discovers operator and boolean literal mutants" {
  let source = "fn f(x : Int) -> Bool { x + 1 == 2 && true }"
  let candidates = @moon_mutest.discover(source, file="sample.mbt")
  inspect(candidates.length(), content="4")
  inspect(candidates[0].rule.label, content="add-to-sub")
  inspect(candidates[1].rule.label, content="eq-to-ne")
  inspect(candidates[2].rule.label, content="and-to-or")
  inspect(candidates[3].rule.label, content="true-to-false")
  inspect(candidates[0].span.file, content="sample.mbt")
}

///|
test "skips strings chars and comments" {
  let source =
    #|fn f(x : Int) -> Bool {
    #|  let text = "true == false && x + 1"
    #|  let slash = '/'
    #|  // false != true
    #|  /* x <= 1 && true */
    #|  x != 3
    #|}
    #|
  let candidates = @moon_mutest.discover(source)
  inspect(candidates.length(), content="1")
  inspect(candidates[0].rule.label, content="ne-to-eq")
}

///|
test "applies a selected mutation" {
  let source = "let ok = left == right"
  let candidates = @moon_mutest.discover(source)
  let mutated = @moon_mutest.apply_mutation(source, candidates[0])
  inspect(mutated, content="let ok = left != right")
}

///|
test "summarizes candidates by mutation kind" {
  let source = "a <= b || false\nx * y > 0"
  let summary = @moon_mutest.summarize(source, file="math.mbt")
  inspect(summary.candidate_count, content="5")
  inspect(summary.relational_count, content="2")
  inspect(summary.arithmetic_count, content="1")
  inspect(summary.logical_count, content="1")
  inspect(summary.boolean_count, content="1")
  inspect(summary.numeric_count, content="0")
  inspect(summary.file, content="math.mbt")
}

///|
test "does not mutate MoonBit structural arrows and range markers" {
  let source =
    #|fn f(x : Int) -> Bool {
    #|  match x {
    #|    0 => false
    #|    _ => x > 1
    #|  }
    #|}
    #|let xs = [ for i in 0..<10 => i ]
    #|
  let candidates = @moon_mutest.discover(source)
  inspect(candidates.length(), content="2")
  inspect(candidates[0].rule.label, content="false-to-true")
  inspect(candidates[1].rule.label, content="gt-to-ge")
}
