///|
test "line and column positions use one based coordinates" {
  let source = "let a = 1\nlet b = a - 1"
  let candidates = discover(source, file="sample.mbt")
  inspect(candidates.length(), content="1")
  inspect(candidates[0].span.line, content="2")
  inspect(candidates[0].span.column, content="11")
  inspect(candidates[0].line_text, content="let b = a - 1")
}

///|
test "line suppression annotation skips candidates on that line" {
  let candidates = discover(
    "let ignored = a == b // mutest:ignore\nlet kept = x != y",
  )
  inspect(candidates.length(), content="1")
  inspect(candidates[0].rule.label, content="ne-to-eq")
}
