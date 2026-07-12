///|
test "summarizes project run results" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("a.mbt", "a == b"),
    @moon_mutest.source_file("b.mbt", "x + y && false"),
  ])
  let results = [
    @moon_mutest.project_result(plan.mutations[0], Killed, detail="test failed"),
    @moon_mutest.project_result(plan.mutations[1], Survived),
    @moon_mutest.project_result(
      plan.mutations[2],
      CompileError,
      detail="type error",
    ),
    @moon_mutest.project_result(plan.mutations[3], Timeout, detail="60s"),
  ]
  let report = @moon_mutest.summarize_project_run(plan, results)
  inspect(report.mutation_count, content="4")
  inspect(report.killed, content="1")
  inspect(report.survived, content="1")
  inspect(report.compile_error, content="1")
  inspect(report.timeout, content="1")
  inspect(report.score_percent, content="50")
  inspect(report.files[0].total, content="1")
  inspect(report.files[1].total, content="3")
}

///|
test "classifies project mutation command sequence" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("a.mbt", "a == b"),
  ])
  let result = @moon_mutest.classify_project_sequence(plan.mutations[0], [
    @moon_mutest.command_success(CheckPhase),
    @moon_mutest.command_failure(TestPhase, 1, stderr="caught"),
  ])
  inspect(result.mutation.global_id, content="0")
  debug_inspect(result.outcome, content="Killed")
  inspect(result.detail, content="caught")
}

///|
test "formats markdown project plan" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("a.mbt", "a == b"),
  ])
  let text = @moon_mutest.format_markdown_project_plan(plan)
  assert_true(text.contains("# Mutation Plan"))
  assert_true(text.contains("| Files | 1 |"))
  assert_true(text.contains("| 0 | a.mbt | 1 | eq-to-ne | `==` -> `!=` |"))
}

///|
test "formats markdown run report" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("a.mbt", "a == b"),
  ])
  let report = @moon_mutest.summarize_project_run(plan, [
    @moon_mutest.project_result(plan.mutations[0], Killed, detail="a | b\nc"),
  ])
  let text = @moon_mutest.format_markdown_run_report(report)
  assert_true(text.contains("# Mutation Testing Report"))
  assert_true(text.contains("| Score | 100% |"))
  assert_true(text.contains("a \\| b c"))
}

///|
test "reports mutation risk and survived diagnostics" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("score.mbt", "value + 1"),
  ])
  let report = @moon_mutest.summarize_project_run(plan, [
    @moon_mutest.project_result(plan.mutations[0], Survived),
  ])
  inspect(@moon_mutest.mutation_risk_level(report), content="high")
  assert_true(
    @moon_mutest.mutation_risk_summary(report).contains("survived mutants"),
  )
  assert_true(
    @moon_mutest.format_survived_diagnostics(report).contains(
      "assert exact numeric results",
    ),
  )
}

///|
test "formats html report with file risk ranking" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("safe.mbt", "a == b"),
    @moon_mutest.source_file("risky.mbt", "value + 1"),
  ])
  let report = @moon_mutest.summarize_project_run(plan, [
    @moon_mutest.project_result(plan.mutations[0], Killed),
    @moon_mutest.project_result(plan.mutations[1], Survived),
  ])
  let ranked = @moon_mutest.risk_ranked_files(report)
  inspect(ranked[0].file, content="risky.mbt")
  inspect(@moon_mutest.file_risk_level(ranked[0]), content="high")
  let html = @moon_mutest.format_html_run_report(report)
  assert_true(html.contains("<!doctype html>"))
  assert_true(html.contains("File Risk Ranking"))
  assert_true(html.contains("Survived Diagnostics"))
  assert_true(html.contains("risky.mbt"))
  assert_true(html.contains("assert exact numeric results"))
}
