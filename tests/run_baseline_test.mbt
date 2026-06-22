///|
fn baseline_commands() -> Array[@moon_mutest.RunnerCommand] {
  [
    { phase: CheckPhase, command: "moon check", timeout_ms: 10 },
    { phase: TestPhase, command: "moon test", timeout_ms: 20 },
  ]
}

///|
test "baseline passes when every expected command succeeds" {
  let report = @moon_mutest.classify_baseline(baseline_commands(), [
    @moon_mutest.command_success(CheckPhase),
    @moon_mutest.command_success(TestPhase),
  ])
  debug_inspect(report.outcome, content="BaselinePassed")
  inspect(report.can_run_mutants, content="true")
  inspect(report.executed_count, content="2")
  assert_true(report.failed_phase is None)
}

///|
test "baseline records command failures" {
  let report = @moon_mutest.classify_baseline(baseline_commands(), [
    @moon_mutest.command_success(CheckPhase),
    @moon_mutest.command_failure(TestPhase, 1, stderr="assertion failed"),
  ])
  debug_inspect(report.outcome, content="BaselineFailed")
  inspect(report.can_run_mutants, content="false")
  debug_inspect(report.failed_index, content="Some(1)")
  debug_inspect(report.failed_phase, content="Some(TestPhase)")
  inspect(report.detail, content="exit code 1: assertion failed")
}

///|
test "baseline records timeouts before later commands matter" {
  let report = @moon_mutest.classify_baseline(baseline_commands(), [
    @moon_mutest.command_timeout(CheckPhase, detail="30s"),
    @moon_mutest.command_success(TestPhase),
  ])
  debug_inspect(report.outcome, content="BaselineTimedOut")
  inspect(report.can_run_mutants, content="false")
  inspect(report.detail, content="30s")
}

///|
test "baseline detects incomplete command sequences" {
  let report = @moon_mutest.classify_baseline(baseline_commands(), [
    @moon_mutest.command_success(CheckPhase),
  ])
  debug_inspect(report.outcome, content="BaselineIncomplete")
  inspect(report.executed_count, content="1")
  inspect(
    report.detail,
    content="baseline stopped before all commands completed",
  )
}

///|
test "baseline failure can skip planned mutation executions" {
  let plan = @moon_mutest.build_execution_plan(
    [@moon_mutest.source_file("a.mbt", "a == b && true")],
    @moon_mutest.MutestConfig::default(),
  )
  let baseline = @moon_mutest.classify_baseline(plan.config.commands, [
    @moon_mutest.command_failure(CheckPhase, 1, stderr="type error"),
  ])
  let skipped = @moon_mutest.skip_execution_results_for_baseline(plan, baseline)
  inspect(plan.executions.length(), content="3")
  inspect(skipped.length(), content="3")
  debug_inspect(skipped[0].outcome, content="Skipped")
  inspect(skipped[0].detail, content="baseline failed: exit code 1: type error")
}

///|
test "baseline skip helper returns no synthetic results after pass" {
  let plan = @moon_mutest.build_execution_plan(
    [@moon_mutest.source_file("a.mbt", "a == b")],
    @moon_mutest.MutestConfig::default(),
  )
  let baseline = @moon_mutest.classify_baseline(plan.config.commands, [
    @moon_mutest.command_success(CheckPhase),
    @moon_mutest.command_success(TestPhase),
  ])
  inspect(
    @moon_mutest.skip_execution_results_for_baseline(plan, baseline).length(),
    content="0",
  )
}

///|
test "formats baseline reports" {
  let report = @moon_mutest.classify_baseline(baseline_commands(), [
    @moon_mutest.command_success(CheckPhase),
  ])
  inspect(
    @moon_mutest.format_baseline_report(report),
    content=(
      #|Baseline report
      #|outcome: incomplete
      #|can-run-mutants: false
      #|commands: 1/2
      #|failed-index: none
      #|failed-phase: none
      #|detail: baseline stopped before all commands completed
    ),
  )
}
