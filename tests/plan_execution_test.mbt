///|
test "builds execution plan from config and files" {
  let config : @moon_mutest.MutestConfig = {
    include_kinds: [],
    include_labels: [],
    line_start: None,
    line_end: None,
    max_mutants: Some(2),
    commands: [{ phase: CheckPhase, command: "moon check", timeout_ms: 10 }],
    fail_fast: true,
    report_format: TextReport,
  }
  let plan = @moon_mutest.build_execution_plan(
    [
      @moon_mutest.source_file("a.mbt", "a == b && true"),
      @moon_mutest.source_file("b.mbt", "x + y"),
    ],
    config,
  )
  inspect(plan.project.mutation_count, content="4")
  inspect(plan.executions.length(), content="2")
  inspect(plan.truncated, content="true")
  inspect(plan.executions[0].edit.original, content="==")
  inspect(plan.executions[0].restore_edit.original, content="!=")
  inspect(plan.executions[0].commands[0].command, content="moon check")
}

///|
test "execution plan can use boundary profile" {
  let config = @moon_mutest.MutestConfig::default()
  let plan = @moon_mutest.build_execution_plan_with_profile(
    [@moon_mutest.source_file("a.mbt", "let n = 0")],
    config,
    BoundaryProfile,
  )
  inspect(plan.project.mutation_count, content="1")
  inspect(
    plan.executions[0].mutation.candidate.rule.label,
    content="zero-to-one",
  )
}

///|
test "execution plan lookup by mutation id" {
  let plan = @moon_mutest.build_execution_plan(
    [@moon_mutest.source_file("a.mbt", "a == b && false")],
    @moon_mutest.MutestConfig::default(),
  )
  match @moon_mutest.execution_by_mutation_id(plan, 1) {
    Some(execution) =>
      inspect(execution.mutation.candidate.rule.label, content="and-to-or")
    None => fail("expected execution")
  }
  assert_true(@moon_mutest.execution_by_mutation_id(plan, 9) is None)
}

///|
test "formats execution plan" {
  let config : @moon_mutest.MutestConfig = {
    include_kinds: [],
    include_labels: [],
    line_start: None,
    line_end: None,
    max_mutants: Some(1),
    commands: [{ phase: TestPhase, command: "moon test", timeout_ms: 20 }],
    fail_fast: true,
    report_format: TextReport,
  }
  let plan = @moon_mutest.build_execution_plan(
    [@moon_mutest.source_file("a.mbt", "a != b")],
    config,
  )
  inspect(
    @moon_mutest.format_execution_plan(plan),
    content=(
      #|Mutation execution plan
      #|files: 1
      #|mutations: 1
      #|executions: 1
      #|truncated: false
      #|commands:
      #|- test: moon test (20 ms)
      #|
      #|mutants:
      #|- #0 a.mbt:1 ne-to-eq
    ),
  )
}
