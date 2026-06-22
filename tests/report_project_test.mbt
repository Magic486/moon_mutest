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
