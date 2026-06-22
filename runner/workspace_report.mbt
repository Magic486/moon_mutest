///|
pub fn format_workspace_snapshot_report(snapshot : WorkspaceSnapshot) -> String {
  let lines : Array[String] = [
    "Workspace snapshot",
    "root: \{snapshot.root}",
    "total-files: \{snapshot.selection.total_files}",
    "included-files: \{snapshot.selection.included_files}",
    "excluded-files: \{snapshot.selection.excluded_files}",
    "source-files: \{snapshot.selection.source_files}",
    "test-files: \{snapshot.selection.test_files}",
    "generated-files: \{snapshot.selection.generated_files}",
  ]
  for decision in snapshot.selection.decisions {
    let action = if decision.included { "include" } else { "exclude" }
    lines.push("- \{decision.path}: \{action} " + "(\{decision.reason})")
  }
  lines.join("\n")
}

///|
pub fn format_workspace_run_markdown(report : WorkspaceRunReport) -> String {
  let lines : Array[String] = [
    "# Workspace Mutation Run",
    "",
    "## Summary",
    "",
    "| Metric | Value |",
    "| --- | ---: |",
    "| Workspace files | \{report.snapshot.selection.included_files}/\{report.snapshot.selection.total_files} |",
    "| Planned mutants | \{report.plan.project.mutation_count} |",
    "| Selected mutants | \{report.selection.selected_count} |",
    "| Executed results | \{report.report.results.length()} |",
    "| Killed | \{report.report.killed} |",
    "| Survived | \{report.report.survived} |",
    "| Compile errors | \{report.report.compile_error} |",
    "| Timeouts | \{report.report.timeout} |",
    "| Skipped | \{report.report.skipped} |",
    "| Score | \{report.report.score_percent}% |",
    "",
    "## Workspace",
    "",
    "| Field | Value |",
    "| --- | --- |",
    "| Root | \{escape_markdown_cell(report.workspace)} |",
    "| Temp workspace | \{escape_markdown_cell(report.temp_workspace)} |",
    "| Temp kept | \{bool_label(report.kept_temp)} |",
    "",
    "## Baseline",
    "",
    "| Field | Value |",
    "| --- | --- |",
    "| Outcome | \{baseline_outcome_label(report.baseline.outcome)} |",
    "| Can run mutants | \{bool_label(report.baseline.can_run_mutants)} |",
    "| Commands | \{report.baseline.executed_count}/\{report.baseline.command_count} |",
    "| Detail | \{escape_markdown_cell(report.baseline.detail)} |",
    "",
  ]
  append_baseline_command_table(lines, report)
  append_file_table(lines, report)
  append_mutant_table(lines, report)
  lines.join("\n")
}

///|
pub fn format_workspace_run_files(report : WorkspaceRunReport) -> String {
  let lines : Array[String] = [
    "Workspace run files",
    "included: \{report.snapshot.selection.included_files}",
    "excluded: \{report.snapshot.selection.excluded_files}",
  ]
  for file in report.report.files {
    lines.push(
      "- \{file.file}: total=\{file.total}, killed=\{file.killed}, " +
      "survived=\{file.survived}, score=\{file.score_percent}%",
    )
  }
  lines.join("\n")
}

///|
fn append_baseline_command_table(
  lines : Array[String],
  report : WorkspaceRunReport,
) -> Unit {
  lines.push("## Baseline Commands")
  lines.push("")
  lines.push("| # | Phase | Exit | Timeout | Detail |")
  lines.push("| ---: | --- | ---: | --- | --- |")
  for index, command in report.baseline_commands {
    lines.push(
      "| \{index} | \{command_phase_label(command.phase)} | " +
      "\{optional_exit_code(command.exit_code)} | " +
      "\{bool_label(command.timed_out)} | " +
      "\{escape_markdown_cell(command_detail(command))} |",
    )
  }
  if report.baseline_commands.is_empty() {
    lines.push("|  |  |  |  | no baseline commands executed |")
  }
  lines.push("")
}

///|
fn append_file_table(
  lines : Array[String],
  report : WorkspaceRunReport,
) -> Unit {
  lines.push("## File Results")
  lines.push("")
  lines.push(
    "| File | Total | Killed | Survived | Compile | Timeout | Skipped | Score |",
  )
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
  for file in report.report.files {
    lines.push(
      "| \{escape_markdown_cell(file.file)} | " +
      "\{file.total} | \{file.killed} | \{file.survived} | " +
      "\{file.compile_error} | \{file.timeout} | \{file.skipped} | " +
      "\{file.score_percent}% |",
    )
  }
  if report.report.files.is_empty() {
    lines.push("|  | 0 | 0 | 0 | 0 | 0 | 0 | 0% |")
  }
  lines.push("")
}

///|
fn append_mutant_table(
  lines : Array[String],
  report : WorkspaceRunReport,
) -> Unit {
  lines.push("## Mutant Results")
  lines.push("")
  lines.push("| ID | Outcome | File | Line | Rule | Change | Detail |")
  lines.push("| ---: | --- | --- | ---: | --- | --- | --- |")
  for result in report.report.results {
    let mutation = result.mutation
    lines.push(
      "| \{mutation.global_id} | \{outcome_label(result.outcome)} | " +
      "\{escape_markdown_cell(mutation.file)} | " +
      "\{mutation.candidate.span.line} | " +
      "\{mutation.candidate.rule.label} | " +
      "`\{escape_backticks(mutation.candidate.original)}` -> " +
      "`\{escape_backticks(mutation.candidate.replacement)}` | " +
      "\{escape_markdown_cell(result.detail)} |",
    )
  }
  if report.report.results.is_empty() {
    lines.push("|  |  |  |  |  |  | no mutant results |")
  }
}

///|
fn command_detail(command : CommandResult) -> String {
  if command.stderr != "" {
    command.stderr
  } else if command.stdout != "" {
    command.stdout
  } else if command.timed_out {
    "timed out"
  } else {
    match command.exit_code {
      Some(code) => "exit code \{code}"
      None => "missing exit code"
    }
  }
}

///|
fn optional_exit_code(code : Int?) -> String {
  match code {
    Some(value) => value.to_string()
    None => ""
  }
}

///|
fn bool_label(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn escape_markdown_cell(text : String) -> String {
  text
  .replace(old="|", new="\\|")
  .replace(old="\r\n", new=" ")
  .replace(old="\n", new=" ")
}

///|
fn escape_backticks(text : String) -> String {
  text.replace(old="`", new="\\`")
}
