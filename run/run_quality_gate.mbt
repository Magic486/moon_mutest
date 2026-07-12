///|
pub(all) enum QualityGateStatus {
  GatePassed
  GateFailed
  GateNoSignal
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityGate {
  min_score_percent : Int
  max_survived : Int?
  max_compile_error : Int?
  max_timeout : Int?
  max_skipped : Int?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityGateViolation {
  metric : String
  actual : Int
  limit : Int
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityGateReport {
  status : QualityGateStatus
  score_percent : Int
  scored_mutants : Int
  total_mutants : Int
  killed : Int
  survived : Int
  compile_error : Int
  timeout : Int
  skipped : Int
  equivalent : Int
  violations : Array[QualityGateViolation]
  message : String
} derive(Debug, Eq, ToJson)

///|
pub fn QualityGate::default() -> QualityGate {
  {
    min_score_percent: 80,
    max_survived: None,
    max_compile_error: Some(0),
    max_timeout: Some(0),
    max_skipped: None,
  }
}

///|
pub fn QualityGate::strict(min_score_percent? : Int = 90) -> QualityGate {
  {
    min_score_percent,
    max_survived: Some(0),
    max_compile_error: Some(0),
    max_timeout: Some(0),
    max_skipped: Some(0),
  }
}

///|
pub fn quality_gate_status_label(status : QualityGateStatus) -> String {
  match status {
    GatePassed => "passed"
    GateFailed => "failed"
    GateNoSignal => "no-signal"
  }
}

///|
pub fn evaluate_quality_gate(
  report : ProjectRunReport,
  gate : QualityGate,
) -> QualityGateReport {
  let violations : Array[QualityGateViolation] = []
  let scored_mutants = report.killed + report.survived
  if scored_mutants > 0 && report.score_percent < gate.min_score_percent {
    violations.push({
      metric: "score_percent",
      actual: report.score_percent,
      limit: gate.min_score_percent,
      message: "mutation score is below the required threshold",
    })
  }
  add_limit_violation(
    violations,
    metric="survived",
    actual=report.survived,
    limit=gate.max_survived,
    message="too many mutants survived",
  )
  add_limit_violation(
    violations,
    metric="compile_error",
    actual=report.compile_error,
    limit=gate.max_compile_error,
    message="too many mutants failed during check/build",
  )
  add_limit_violation(
    violations,
    metric="timeout",
    actual=report.timeout,
    limit=gate.max_timeout,
    message="too many mutants timed out",
  )
  add_limit_violation(
    violations,
    metric="skipped",
    actual=report.skipped,
    limit=gate.max_skipped,
    message="too many mutants were skipped",
  )
  let status = if !violations.is_empty() {
    GateFailed
  } else if scored_mutants == 0 {
    GateNoSignal
  } else {
    GatePassed
  }
  {
    status,
    score_percent: report.score_percent,
    scored_mutants,
    total_mutants: report.mutation_count,
    killed: report.killed,
    survived: report.survived,
    compile_error: report.compile_error,
    timeout: report.timeout,
    skipped: report.skipped,
    equivalent: report.equivalent,
    violations,
    message: quality_gate_message(status, violations.length(), scored_mutants),
  }
}

///|
pub fn evaluate_quality_gate_after_baseline(
  report : ProjectRunReport,
  gate : QualityGate,
  baseline : BaselineReport,
) -> QualityGateReport {
  if baseline.can_run_mutants {
    evaluate_quality_gate(report, gate)
  } else {
    let violation = {
      metric: "baseline",
      actual: 0,
      limit: 1,
      message: "baseline did not pass: \{baseline.detail}",
    }
    {
      status: GateFailed,
      score_percent: report.score_percent,
      scored_mutants: report.killed + report.survived,
      total_mutants: report.mutation_count,
      killed: report.killed,
      survived: report.survived,
      compile_error: report.compile_error,
      timeout: report.timeout,
      skipped: report.skipped,
      equivalent: report.equivalent,
      violations: [violation],
      message: "baseline must pass before mutation quality can be trusted",
    }
  }
}

///|
pub fn format_quality_gate(gate : QualityGate) -> String {
  [
    "Quality gate",
    "min-score-percent: \{gate.min_score_percent}",
    "max-survived: \{format_gate_limit(gate.max_survived)}",
    "max-compile-error: \{format_gate_limit(gate.max_compile_error)}",
    "max-timeout: \{format_gate_limit(gate.max_timeout)}",
    "max-skipped: \{format_gate_limit(gate.max_skipped)}",
  ].join("\n")
}

///|
pub fn format_quality_gate_report(report : QualityGateReport) -> String {
  let lines : Array[String] = [
    "Quality gate report",
    "status: \{quality_gate_status_label(report.status)}",
    "score: \{report.score_percent}%",
    "scored-mutants: \{report.scored_mutants}",
    "total-mutants: \{report.total_mutants}",
    "killed: \{report.killed}",
    "survived: \{report.survived}",
    "compile-error: \{report.compile_error}",
    "timeout: \{report.timeout}",
    "skipped: \{report.skipped}",
    "equivalent: \{report.equivalent}",
    "message: \{report.message}",
  ]
  if report.violations.is_empty() {
    lines.push("violations: none")
  } else {
    lines.push("violations:")
    for violation in report.violations {
      lines.push(
        "- \{violation.metric}: actual=\{violation.actual}, " +
        "limit=\{violation.limit}, \{violation.message}",
      )
    }
  }
  lines.join("\n")
}

///|
fn add_limit_violation(
  violations : Array[QualityGateViolation],
  metric~ : String,
  actual~ : Int,
  limit~ : Int?,
  message~ : String,
) -> Unit {
  match limit {
    Some(max) =>
      if actual > max {
        violations.push({ metric, actual, limit: max, message })
      }
    None => ()
  }
}

///|
fn quality_gate_message(
  status : QualityGateStatus,
  violation_count : Int,
  scored_mutants : Int,
) -> String {
  match status {
    GatePassed => "quality gate passed"
    GateFailed => "\{violation_count} quality gate violation(s)"
    GateNoSignal =>
      if scored_mutants == 0 {
        "no killed or survived mutants were available for scoring"
      } else {
        "quality gate could not produce a signal"
      }
  }
}

///|
fn format_gate_limit(limit : Int?) -> String {
  match limit {
    Some(value) => value.to_string()
    None => "unlimited"
  }
}
