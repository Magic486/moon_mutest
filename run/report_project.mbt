///|
pub(all) struct ProjectMutantResult {
  mutation : ProjectMutation
  outcome : MutantOutcome
  detail : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct FileRunReport {
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
pub(all) struct ProjectRunReport {
  file_count : Int
  mutation_count : Int
  killed : Int
  survived : Int
  compile_error : Int
  timeout : Int
  skipped : Int
  score_percent : Int
  files : Array[FileRunReport]
  results : Array[ProjectMutantResult]
} derive(Debug, Eq, ToJson)

///|
pub fn project_result(
  mutation : ProjectMutation,
  outcome : MutantOutcome,
  detail? : String = "",
) -> ProjectMutantResult {
  { mutation, outcome, detail }
}

///|
pub fn classify_project_sequence(
  mutation : ProjectMutation,
  commands : ArrayView[CommandResult],
) -> ProjectMutantResult {
  let classified = classify_sequence(mutation.candidate, commands)
  project_result(mutation, classified.outcome, detail=classified.detail)
}

///|
pub fn summarize_project_run(
  plan : ProjectMutationPlan,
  results : ArrayView[ProjectMutantResult],
) -> ProjectRunReport {
  let files : Array[FileRunReport] = []
  for file in plan.files {
    files.push(summarize_file_run(file.file, results))
  }
  let totals = summarize_project_totals(results)
  {
    file_count: plan.file_count,
    mutation_count: plan.mutation_count,
    killed: totals.killed,
    survived: totals.survived,
    compile_error: totals.compile_error,
    timeout: totals.timeout,
    skipped: totals.skipped,
    score_percent: totals.score_percent,
    files,
    results: results.to_owned(),
  }
}

///|
fn summarize_file_run(
  file : String,
  results : ArrayView[ProjectMutantResult],
) -> FileRunReport {
  let file_results = [
    for result in results if result.mutation.file == file => result
  ]
  let totals = summarize_project_totals(file_results)
  {
    file,
    total: file_results.length(),
    killed: totals.killed,
    survived: totals.survived,
    compile_error: totals.compile_error,
    timeout: totals.timeout,
    skipped: totals.skipped,
    score_percent: totals.score_percent,
  }
}

///|
fn summarize_project_totals(
  results : ArrayView[ProjectMutantResult],
) -> MutationRunReport {
  let mut killed = 0
  let mut survived = 0
  let mut compile_error = 0
  let mut timeout = 0
  let mut skipped = 0
  for result in results {
    match result.outcome {
      Killed => killed += 1
      Survived => survived += 1
      CompileError => compile_error += 1
      Timeout => timeout += 1
      Skipped => skipped += 1
    }
  }
  let scored = killed + survived
  {
    file: "<project>",
    total: results.length(),
    killed,
    survived,
    compile_error,
    timeout,
    skipped,
    score_percent: if scored == 0 {
      0
    } else {
      killed * 100 / scored
    },
  }
}

///|
pub fn format_markdown_project_plan(plan : ProjectMutationPlan) -> String {
  let lines : Array[String] = [
    "# Mutation Plan",
    "",
    "| Metric | Value |",
    "| --- | ---: |",
    "| Files | \{plan.file_count} |",
    "| Mutations | \{plan.mutation_count} |",
    "",
    "## Files",
    "",
    "| File | Candidates | ID Range |",
    "| --- | ---: | --- |",
  ]
  for file in plan.files {
    lines.push(
      "| \{file.file} | \{file.summary.candidate_count} | " +
      "\{file.start_id}..\{file.end_id} |",
    )
  }
  lines.push("")
  lines.push("## Mutations")
  lines.push("")
  lines.push("| ID | File | Line | Rule | Change |")
  lines.push("| ---: | --- | ---: | --- | --- |")
  for mutation in plan.mutations {
    lines.push(
      "| \{mutation.global_id} | \{mutation.file} | " +
      "\{mutation.candidate.span.line} | \{mutation.candidate.rule.label} | " +
      "`\{mutation.candidate.original}` -> `\{mutation.candidate.replacement}` |",
    )
  }
  lines.join("\n")
}

///|
pub fn format_markdown_run_report(report : ProjectRunReport) -> String {
  let lines : Array[String] = [
    "# Mutation Testing Report",
    "",
    "| Metric | Value |",
    "| --- | ---: |",
    "| Files | \{report.file_count} |",
    "| Mutations | \{report.mutation_count} |",
    "| Killed | \{report.killed} |",
    "| Survived | \{report.survived} |",
    "| Compile errors | \{report.compile_error} |",
    "| Timeouts | \{report.timeout} |",
    "| Skipped | \{report.skipped} |",
    "| Score | \{report.score_percent}% |",
    "",
    "## File Summary",
    "",
    "| File | Total | Killed | Survived | Score |",
    "| --- | ---: | ---: | ---: | ---: |",
  ]
  for file in report.files {
    lines.push(
      "| \{file.file} | \{file.total} | \{file.killed} | " +
      "\{file.survived} | \{file.score_percent}% |",
    )
  }
  lines.push("")
  lines.push("## Mutant Results")
  lines.push("")
  lines.push("| ID | Outcome | File | Line | Rule | Detail |")
  lines.push("| ---: | --- | --- | ---: | --- | --- |")
  for result in report.results {
    let mutation = result.mutation
    lines.push(
      "| \{mutation.global_id} | \{outcome_label(result.outcome)} | " +
      "\{mutation.file} | \{mutation.candidate.span.line} | " +
      "\{mutation.candidate.rule.label} | \{escape_markdown_cell(result.detail)} |",
    )
  }
  lines.join("\n")
}

///|
fn escape_markdown_cell(text : String) -> String {
  if text == "" {
    ""
  } else {
    text.replace(old="|", new="\\|").replace(old="\n", new=" ")
  }
}
