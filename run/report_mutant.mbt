///|
pub(all) enum MutantOutcome {
  Killed
  Survived
  CompileError
  Timeout
  Skipped
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MutantResult {
  candidate : MutationCandidate
  outcome : MutantOutcome
  detail : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MutationRunReport {
  file : String
  total : Int
  killed : Int
  survived : Int
  compile_error : Int
  timeout : Int
  skipped : Int
  score_percent : Int
} derive(Debug, Eq, ToJson)

///|
pub fn outcome_label(outcome : MutantOutcome) -> String {
  match outcome {
    Killed => "killed"
    Survived => "survived"
    CompileError => "compile-error"
    Timeout => "timeout"
    Skipped => "skipped"
  }
}

///|
pub fn result(
  candidate : MutationCandidate,
  outcome : MutantOutcome,
  detail? : String = "",
) -> MutantResult {
  { candidate, outcome, detail }
}

///|
pub fn summarize_results(
  file : String,
  results : ArrayView[MutantResult],
) -> MutationRunReport {
  let mut killed = 0
  let mut survived = 0
  let mut compile_error = 0
  let mut timeout = 0
  let mut skipped = 0
  for item in results {
    match item.outcome {
      Killed => killed += 1
      Survived => survived += 1
      CompileError => compile_error += 1
      Timeout => timeout += 1
      Skipped => skipped += 1
    }
  }
  let scored = killed + survived
  let score_percent = if scored == 0 { 0 } else { killed * 100 / scored }
  {
    file,
    total: results.length(),
    killed,
    survived,
    compile_error,
    timeout,
    skipped,
    score_percent,
  }
}

///|
pub fn format_run_report(report : MutationRunReport) -> String {
  [
    "Mutation report for \{report.file}",
    "total: \{report.total}",
    "killed: \{report.killed}",
    "survived: \{report.survived}",
    "compile-error: \{report.compile_error}",
    "timeout: \{report.timeout}",
    "skipped: \{report.skipped}",
    "score: \{report.score_percent}%",
  ].join("\n")
}

///|
pub fn format_result(result : MutantResult) -> String {
  let candidate = result.candidate
  let base = "#\{candidate.id} \{outcome_label(result.outcome)} " +
    "\{candidate.span.file}:\{candidate.span.line}:\{candidate.span.column} " +
    "\{candidate.rule.label} \{candidate.original} -> \{candidate.replacement}"
  if result.detail == "" {
    base
  } else {
    base + " -- " + result.detail
  }
}
