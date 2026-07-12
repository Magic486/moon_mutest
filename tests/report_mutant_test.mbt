///|
test "summarizes mutant outcomes into score" {
  let candidates = @moon_mutest.discover("a == b && true", file="sample.mbt")
  let results = [
    @moon_mutest.result(candidates[0], Killed, detail="test failed"),
    @moon_mutest.result(candidates[1], Survived),
    @moon_mutest.result(candidates[2], CompileError, detail="invalid mutant"),
  ]
  let report = @moon_mutest.summarize_results("sample.mbt", results)
  inspect(report.total, content="3")
  inspect(report.killed, content="1")
  inspect(report.survived, content="1")
  inspect(report.compile_error, content="1")
  inspect(report.score_percent, content="50")
}

///|
test "formats report and individual results" {
  let candidates = @moon_mutest.discover("a != b", file="sample.mbt")
  let result = @moon_mutest.result(
    candidates[0],
    Killed,
    detail="moon test failed",
  )
  inspect(
    @moon_mutest.format_result(result),
    content="#0 killed sample.mbt:1:3 ne-to-eq != -> == -- moon test failed",
  )
  inspect(
    @moon_mutest.format_run_report(
      @moon_mutest.summarize_results("sample.mbt", [result]),
    ),
    content=(
      #|Mutation report for sample.mbt
      #|total: 1
      #|killed: 1
      #|survived: 0
      #|compile-error: 0
      #|timeout: 0
      #|skipped: 0
      #|equivalent: 0
      #|score: 100%
    ),
  )
}

///|
test "equivalent mutants stay visible without lowering the score" {
  let candidates = @moon_mutest.discover("a == b", file="sample.mbt")
  let report = @moon_mutest.summarize_results("sample.mbt", [
    @moon_mutest.result(candidates[0], Equivalent, detail="domain invariant"),
  ])
  inspect(report.equivalent, content="1")
  inspect(report.score_percent, content="0")
  assert_true(@moon_mutest.format_run_report(report).contains("equivalent: 1"))
}
