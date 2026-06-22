///|
fn gate_plan() -> @moon_mutest.ProjectMutationPlan {
  @moon_mutest.plan_project([
    @moon_mutest.source_file("a.mbt", "a == b && false || x + y"),
  ])
}

///|
fn gate_report_with_outcomes(
  outcomes : Array[@moon_mutest.MutantOutcome],
) -> @moon_mutest.ProjectRunReport {
  let plan = gate_plan()
  let results : Array[@moon_mutest.ProjectMutantResult] = []
  for index, outcome in outcomes {
    results.push(@moon_mutest.project_result(plan.mutations[index], outcome))
  }
  @moon_mutest.summarize_project_run(plan, results)
}

///|
test "quality gate passes at the default threshold" {
  let report = gate_report_with_outcomes([
    Killed,
    Killed,
    Killed,
    Killed,
    Survived,
  ])
  let gate = @moon_mutest.QualityGate::default()
  let result = @moon_mutest.evaluate_quality_gate(report, gate)
  inspect(report.mutation_count, content="5")
  inspect(result.score_percent, content="80")
  debug_inspect(result.status, content="GatePassed")
  inspect(result.violations.length(), content="0")
}

///|
test "quality gate fails when score is below threshold" {
  let report = gate_report_with_outcomes([
    Killed,
    Killed,
    Survived,
    Survived,
    Survived,
  ])
  let gate = @moon_mutest.QualityGate::default()
  let result = @moon_mutest.evaluate_quality_gate(report, gate)
  inspect(result.score_percent, content="40")
  debug_inspect(result.status, content="GateFailed")
  inspect(result.violations[0].metric, content="score_percent")
  inspect(result.violations[0].actual, content="40")
  inspect(result.violations[0].limit, content="80")
}

///|
test "quality gate can enforce strict survived and skipped limits" {
  let report = gate_report_with_outcomes([
    Killed,
    Killed,
    Killed,
    Killed,
    Skipped,
  ])
  let gate = @moon_mutest.QualityGate::strict(min_score_percent=90)
  let result = @moon_mutest.evaluate_quality_gate(report, gate)
  debug_inspect(result.status, content="GateFailed")
  inspect(result.violations.length(), content="1")
  inspect(result.violations[0].metric, content="skipped")
}

///|
test "default quality gate fails compile errors and timeouts" {
  let report = gate_report_with_outcomes([
    Killed,
    Killed,
    CompileError,
    Timeout,
    Killed,
  ])
  let result = @moon_mutest.evaluate_quality_gate(
    report,
    @moon_mutest.QualityGate::default(),
  )
  debug_inspect(result.status, content="GateFailed")
  inspect(result.violations.length(), content="2")
  inspect(result.violations[0].metric, content="compile_error")
  inspect(result.violations[1].metric, content="timeout")
}

///|
test "quality gate reports no signal when nothing was scored" {
  let report = gate_report_with_outcomes([
    Skipped,
    Skipped,
    Skipped,
    Skipped,
    Skipped,
  ])
  let result = @moon_mutest.evaluate_quality_gate(
    report,
    @moon_mutest.QualityGate::default(),
  )
  debug_inspect(result.status, content="GateNoSignal")
  inspect(
    result.message,
    content="no killed or survived mutants were available for scoring",
  )
}

///|
test "quality gate can account for baseline failures" {
  let report = gate_report_with_outcomes([
    Skipped,
    Skipped,
    Skipped,
    Skipped,
    Skipped,
  ])
  let baseline = @moon_mutest.classify_baseline(
    [{ phase: CheckPhase, command: "moon check", timeout_ms: 10 }],
    [@moon_mutest.command_failure(CheckPhase, 1, stderr="type error")],
  )
  let result = @moon_mutest.evaluate_quality_gate_after_baseline(
    report,
    @moon_mutest.QualityGate::default(),
    baseline,
  )
  debug_inspect(result.status, content="GateFailed")
  inspect(result.violations[0].metric, content="baseline")
  assert_true(result.violations[0].message.contains("type error"))
}

///|
test "formats quality gate reports" {
  let report = gate_report_with_outcomes([
    Killed,
    Killed,
    Survived,
    Survived,
    Survived,
  ])
  let result = @moon_mutest.evaluate_quality_gate(
    report,
    @moon_mutest.QualityGate::default(),
  )
  inspect(
    @moon_mutest.format_quality_gate_report(result),
    content=(
      #|Quality gate report
      #|status: failed
      #|score: 40%
      #|scored-mutants: 5
      #|total-mutants: 5
      #|killed: 2
      #|survived: 3
      #|compile-error: 0
      #|timeout: 0
      #|skipped: 0
      #|message: 1 quality gate violation(s)
      #|violations:
      #|- score_percent: actual=40, limit=80, mutation score is below the required threshold
    ),
  )
}

///|
test "formats quality gate configuration" {
  inspect(
    @moon_mutest.format_quality_gate(@moon_mutest.QualityGate::strict()),
    content=(
      #|Quality gate
      #|min-score-percent: 90
      #|max-survived: 0
      #|max-compile-error: 0
      #|max-timeout: 0
      #|max-skipped: 0
    ),
  )
}
