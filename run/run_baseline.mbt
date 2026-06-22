///|
pub(all) enum BaselineOutcome {
  BaselinePassed
  BaselineFailed
  BaselineTimedOut
  BaselineIncomplete
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BaselineReport {
  outcome : BaselineOutcome
  command_count : Int
  executed_count : Int
  failed_index : Int?
  failed_phase : CommandPhase?
  can_run_mutants : Bool
  detail : String
} derive(Debug, Eq, ToJson)

///|
pub fn baseline_outcome_label(outcome : BaselineOutcome) -> String {
  match outcome {
    BaselinePassed => "passed"
    BaselineFailed => "failed"
    BaselineTimedOut => "timed-out"
    BaselineIncomplete => "incomplete"
  }
}

///|
pub fn classify_baseline(
  expected : ArrayView[RunnerCommand],
  results : ArrayView[CommandResult],
) -> BaselineReport {
  for index, result in results {
    if result.timed_out {
      break baseline_report(
        BaselineTimedOut,
        command_count=expected.length(),
        executed_count=results.length(),
        failed_index=Some(index),
        failed_phase=Some(result.phase),
        detail=command_failure_detail(result),
      )
    } else {
      match result.exit_code {
        Some(0) => ()
        Some(code) =>
          break baseline_report(
            BaselineFailed,
            command_count=expected.length(),
            executed_count=results.length(),
            failed_index=Some(index),
            failed_phase=Some(result.phase),
            detail="exit code \{code}: \{command_failure_detail(result)}",
          )
        None =>
          break baseline_report(
            BaselineIncomplete,
            command_count=expected.length(),
            executed_count=results.length(),
            failed_index=Some(index),
            failed_phase=Some(result.phase),
            detail="command did not produce an exit code",
          )
      }
    }
  } nobreak {
    if results.length() < expected.length() {
      baseline_report(
        BaselineIncomplete,
        command_count=expected.length(),
        executed_count=results.length(),
        failed_index=None,
        failed_phase=None,
        detail="baseline stopped before all commands completed",
      )
    } else {
      baseline_report(
        BaselinePassed,
        command_count=expected.length(),
        executed_count=results.length(),
        failed_index=None,
        failed_phase=None,
        detail="baseline commands passed",
      )
    }
  }
}

///|
pub fn baseline_can_run(report : BaselineReport) -> Bool {
  report.can_run_mutants
}

///|
pub fn skip_execution_results_for_baseline(
  plan : ExecutionPlan,
  report : BaselineReport,
) -> Array[ProjectMutantResult] {
  if report.can_run_mutants {
    []
  } else {
    let skipped : Array[ProjectMutantResult] = []
    for execution in plan.executions {
      skipped.push(
        project_result(
          execution.mutation,
          Skipped,
          detail=baseline_skip_detail(report),
        ),
      )
    }
    skipped
  }
}

///|
pub fn format_baseline_report(report : BaselineReport) -> String {
  [
    "Baseline report",
    "outcome: \{baseline_outcome_label(report.outcome)}",
    "can-run-mutants: \{report.can_run_mutants}",
    "commands: \{report.executed_count}/\{report.command_count}",
    "failed-index: \{format_optional_report_int(report.failed_index)}",
    "failed-phase: \{format_optional_phase(report.failed_phase)}",
    "detail: \{report.detail}",
  ].join("\n")
}

///|
fn baseline_report(
  outcome : BaselineOutcome,
  command_count~ : Int,
  executed_count~ : Int,
  failed_index~ : Int?,
  failed_phase~ : CommandPhase?,
  detail~ : String,
) -> BaselineReport {
  {
    outcome,
    command_count,
    executed_count,
    failed_index,
    failed_phase,
    can_run_mutants: outcome == BaselinePassed,
    detail,
  }
}

///|
fn command_failure_detail(result : CommandResult) -> String {
  if result.stderr != "" {
    result.stderr
  } else if result.stdout != "" {
    result.stdout
  } else if result.timed_out {
    "command timed out"
  } else {
    match result.exit_code {
      Some(code) => "exit code \{code}"
      None => "missing exit code"
    }
  }
}

///|
fn baseline_skip_detail(report : BaselineReport) -> String {
  "baseline \{baseline_outcome_label(report.outcome)}: \{report.detail}"
}

///|
fn format_optional_report_int(value : Int?) -> String {
  match value {
    Some(n) => n.to_string()
    None => "none"
  }
}

///|
fn format_optional_phase(value : CommandPhase?) -> String {
  match value {
    Some(phase) => command_phase_label(phase)
    None => "none"
  }
}
