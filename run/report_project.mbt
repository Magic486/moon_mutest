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
  equivalent : Int
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
  equivalent : Int
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
    equivalent: totals.equivalent,
    score_percent: totals.score_percent,
    files,
    results: results.to_owned(),
  }
}

///|
pub fn mutation_risk_level(report : ProjectRunReport) -> String {
  if report.survived > 0 || report.score_percent < 50 {
    "high"
  } else if report.compile_error > 0 ||
    report.timeout > 0 ||
    report.skipped > 0 ||
    report.score_percent < 80 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn file_risk_level(file : FileRunReport) -> String {
  let scored = file.killed + file.survived
  if file.survived > 0 || (scored > 0 && file.score_percent < 50) {
    "high"
  } else if file.compile_error > 0 ||
    file.timeout > 0 ||
    file.skipped > 0 ||
    (scored > 0 && file.score_percent < 80) {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn risk_ranked_files(report : ProjectRunReport) -> Array[FileRunReport] {
  let files = [ for file in report.files => file ]
  for i in 0..<files.length() {
    for j in (i + 1)..<files.length() {
      if file_risk_score(files[j]) > file_risk_score(files[i]) {
        let tmp = files[i]
        files[i] = files[j]
        files[j] = tmp
      }
    }
  }
  files
}

///|
pub fn mutation_risk_summary(report : ProjectRunReport) -> String {
  match mutation_risk_level(report) {
    "high" =>
      "high: survived mutants or very low score indicate weak assertions"
    "medium" =>
      "medium: review compile errors, timeouts, skipped mutants, or score gaps"
    _ =>
      "low: selected mutants were killed and the run produced a useful signal"
  }
}

///|
fn file_risk_score(file : FileRunReport) -> Int {
  let scored = file.killed + file.survived
  let score_gap = if scored == 0 { 0 } else { 100 - file.score_percent }
  file.survived * 10000 +
  score_gap * 100 +
  file.compile_error * 50 +
  file.timeout * 50 +
  file.skipped * 25
}

///|
pub fn diagnose_mutant_result(result : ProjectMutantResult) -> String {
  let candidate = result.mutation.candidate
  match candidate.rule.label {
    "eq-to-ne" | "ne-to-eq" =>
      "add assertions for both equal and non-equal cases around this branch"
    "and-to-or" | "or-to-and" =>
      "add tests where each side of the boolean expression independently changes the result"
    "true-to-false" | "false-to-true" =>
      "assert the observable behavior of this boolean decision, not only that the path runs"
    "add-to-sub" | "sub-to-add" | "mul-to-div" | "div-to-mul" =>
      "assert exact numeric results and include boundary values for this calculation"
    "lt-to-le" | "le-to-lt" | "gt-to-ge" | "ge-to-gt" =>
      "add boundary tests for values exactly at and just outside this comparison limit"
    "zero-to-one" | "one-to-zero" | "minus-one-to-zero" =>
      "add tests for numeric sentinel and boundary values near this literal"
    _ =>
      "add a focused assertion that would fail if this replacement changed behavior"
  }
}

///|
pub fn format_survived_diagnostics(report : ProjectRunReport) -> String {
  let lines : Array[String] = ["Survived mutant diagnostics"]
  for result in report.results {
    if result.outcome == Survived {
      let mutation = result.mutation
      let candidate = mutation.candidate
      lines.push(
        "- #\{mutation.global_id} \{mutation.file}:\{candidate.span.line} " +
        "\{candidate.rule.label} `\{candidate.original}` -> " +
        "`\{candidate.replacement}`: \{diagnose_mutant_result(result)}",
      )
    }
  }
  if lines.length() == 1 {
    lines.push("none")
  }
  lines.join("\n")
}

///|
pub fn format_html_run_report(report : ProjectRunReport) -> String {
  let lines : Array[String] = [
    "<!doctype html>",
    "<html lang=\"en\">",
    "<head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>moon_mutest report</title>",
    html_styles(),
    "</head>",
    "<body>",
    "<main>",
    "<header class=\"hero\">",
    "<p class=\"eyebrow\">moon_mutest</p>",
    "<h1>Mutation Testing Report</h1>",
    "<p class=\"summary\">\{escape_html(mutation_risk_summary(report))}</p>",
    "</header>",
    "<section class=\"cards\">",
    html_metric_card(
      "Score",
      "\{report.score_percent}%",
      mutation_risk_level(report),
    ),
    html_metric_card("Killed", report.killed.to_string(), "low"),
    html_metric_card(
      "Survived",
      report.survived.to_string(),
      if report.survived > 0 {
        "high"
      } else {
        "low"
      },
    ),
    html_metric_card("Files", report.file_count.to_string(), "neutral"),
    "</section>",
    "<section class=\"panel\">",
    "<div class=\"panel-title\"><h2>Overall Signal</h2><span class=\"badge \{mutation_risk_level(report)}\">\{mutation_risk_level(report)}</span></div>",
    "<div class=\"bar\"><span style=\"width: \{html_percent(report.score_percent)}%\"></span></div>",
    "<table>",
    "<tbody>",
    html_pair_row("Mutations", report.mutation_count.to_string()),
    html_pair_row("Executed results", report.results.length().to_string()),
    html_pair_row("Compile errors", report.compile_error.to_string()),
    html_pair_row("Timeouts", report.timeout.to_string()),
    html_pair_row("Skipped", report.skipped.to_string()),
    html_pair_row("Equivalent", report.equivalent.to_string()),
    "</tbody>",
    "</table>",
    "</section>",
  ]
  append_html_file_ranking(lines, report)
  append_html_survived_diagnostics(lines, report)
  append_html_mutant_results(lines, report)
  lines.push("</main>")
  lines.push("</body>")
  lines.push("</html>")
  lines.join("\n")
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
    equivalent: totals.equivalent,
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
  let mut equivalent = 0
  for result in results {
    match result.outcome {
      Killed => killed += 1
      Survived => survived += 1
      CompileError => compile_error += 1
      Timeout => timeout += 1
      Skipped => skipped += 1
      Equivalent => equivalent += 1
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
    equivalent,
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
fn append_html_file_ranking(
  lines : Array[String],
  report : ProjectRunReport,
) -> Unit {
  lines.push("<section class=\"panel\">")
  lines.push("<h2>File Risk Ranking</h2>")
  lines.push("<table>")
  lines.push(
    "<thead><tr><th>#</th><th>File</th><th>Risk</th><th>Total</th><th>Killed</th><th>Survived</th><th>Score</th></tr></thead>",
  )
  lines.push("<tbody>")
  for index, file in risk_ranked_files(report) {
    let risk = file_risk_level(file)
    lines.push(
      "<tr><td>\{index + 1}</td><td><code>\{escape_html(file.file)}</code></td>" +
      "<td><span class=\"badge \{risk}\">\{risk}</span></td>" +
      "<td>\{file.total}</td><td>\{file.killed}</td><td>\{file.survived}</td>" +
      "<td>\{file.score_percent}%</td></tr>",
    )
  }
  if report.files.is_empty() {
    lines.push("<tr><td colspan=\"7\">No files were reported.</td></tr>")
  }
  lines.push("</tbody>")
  lines.push("</table>")
  lines.push("</section>")
}

///|
fn append_html_survived_diagnostics(
  lines : Array[String],
  report : ProjectRunReport,
) -> Unit {
  lines.push("<section class=\"panel\">")
  lines.push("<h2>Survived Diagnostics</h2>")
  if report.survived == 0 {
    lines.push(
      "<p class=\"muted\">No survived mutants in the selected run.</p>",
    )
  } else {
    lines.push("<ul class=\"diagnostics\">")
    for result in report.results {
      if result.outcome == Survived {
        let mutation = result.mutation
        let candidate = mutation.candidate
        lines.push(
          "<li><strong>#\{mutation.global_id}</strong> " +
          "<code>\{escape_html(mutation.file)}:\{candidate.span.line}</code> " +
          "<span class=\"badge high\">\{escape_html(candidate.rule.label)}</span> " +
          "<code>\{escape_html(candidate.original)}</code> -> " +
          "<code>\{escape_html(candidate.replacement)}</code><br>" +
          "<span>\{escape_html(diagnose_mutant_result(result))}</span></li>",
        )
      }
    }
    lines.push("</ul>")
  }
  lines.push("</section>")
}

///|
fn append_html_mutant_results(
  lines : Array[String],
  report : ProjectRunReport,
) -> Unit {
  lines.push("<section class=\"panel\">")
  lines.push("<h2>Mutant Results</h2>")
  lines.push("<table>")
  lines.push(
    "<thead><tr><th>ID</th><th>Outcome</th><th>File</th><th>Line</th><th>Rule</th><th>Change</th><th>Detail</th></tr></thead>",
  )
  lines.push("<tbody>")
  for result in report.results {
    let mutation = result.mutation
    let candidate = mutation.candidate
    lines.push(
      "<tr><td>\{mutation.global_id}</td>" +
      "<td><span class=\"badge \{outcome_html_class(result.outcome)}\">\{escape_html(outcome_label(result.outcome))}</span></td>" +
      "<td><code>\{escape_html(mutation.file)}</code></td>" +
      "<td>\{candidate.span.line}</td>" +
      "<td>\{escape_html(candidate.rule.label)}</td>" +
      "<td><code>\{escape_html(candidate.original)}</code> -> <code>\{escape_html(candidate.replacement)}</code></td>" +
      "<td>\{escape_html(result.detail)}</td></tr>",
    )
  }
  if report.results.is_empty() {
    lines.push("<tr><td colspan=\"7\">No mutants were executed.</td></tr>")
  }
  lines.push("</tbody>")
  lines.push("</table>")
  lines.push("</section>")
}

///|
fn html_metric_card(label : String, value : String, risk : String) -> String {
  "<article class=\"card\"><span>\{escape_html(label)}</span><strong>\{escape_html(value)}</strong><em class=\"\{risk}\">\{escape_html(risk)}</em></article>"
}

///|
fn html_pair_row(label : String, value : String) -> String {
  "<tr><th>\{escape_html(label)}</th><td>\{escape_html(value)}</td></tr>"
}

///|
fn html_percent(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 100 {
    100
  } else {
    value
  }
}

///|
fn outcome_html_class(outcome : MutantOutcome) -> String {
  match outcome {
    Killed => "low"
    Survived => "high"
    CompileError | Timeout | Skipped => "medium"
    Equivalent => "neutral"
  }
}

///|
fn escape_html(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
  .replace(old="\"", new="&quot;")
}

///|
fn html_styles() -> String {
  (
    #|<style>
    #|:root { color-scheme: light; --ink:#172033; --muted:#697386; --line:#d8dde8; --panel:#ffffff; --bg:#f4f7fb; --high:#b42318; --medium:#b54708; --low:#067647; --accent:#2563eb; }
    #|* { box-sizing: border-box; }
    #|body { margin: 0; background: var(--bg); color: var(--ink); font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    #|main { width: min(1180px, calc(100% - 32px)); margin: 0 auto; padding: 32px 0 48px; }
    #|.hero { margin-bottom: 20px; }
    #|.eyebrow { margin: 0 0 6px; color: var(--accent); font-weight: 700; letter-spacing: 0; }
    #|h1 { margin: 0; font-size: 34px; line-height: 1.15; }
    #|h2 { margin: 0 0 16px; font-size: 20px; }
    #|.summary { margin: 10px 0 0; color: var(--muted); max-width: 760px; }
    #|.cards { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 20px 0; }
    #|.card, .panel { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; box-shadow: 0 1px 2px rgba(15, 23, 42, .04); }
    #|.card { padding: 16px; min-height: 110px; }
    #|.card span { display: block; color: var(--muted); font-size: 13px; }
    #|.card strong { display: block; margin-top: 10px; font-size: 30px; }
    #|.card em { display: inline-block; margin-top: 10px; font-style: normal; font-size: 12px; font-weight: 700; }
    #|.panel { padding: 18px; margin-top: 14px; overflow-x: auto; }
    #|.panel-title { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
    #|.bar { height: 12px; background: #e6ebf3; border-radius: 999px; overflow: hidden; margin: 14px 0; }
    #|.bar span { display: block; height: 100%; background: var(--accent); }
    #|table { width: 100%; border-collapse: collapse; font-size: 14px; }
    #|th, td { padding: 10px 8px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }
    #|thead th { color: var(--muted); font-weight: 700; }
    #|code { background: #eef2f7; border-radius: 4px; padding: 2px 4px; font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 13px; }
    #|.badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 2px 8px; font-size: 12px; font-weight: 700; }
    #|.high { color: var(--high); background: #fef3f2; }
    #|.medium { color: var(--medium); background: #fff7ed; }
    #|.low { color: var(--low); background: #ecfdf3; }
    #|.neutral { color: #344054; background: #f2f4f7; }
    #|.muted { color: var(--muted); }
    #|.diagnostics { margin: 0; padding-left: 20px; }
    #|.diagnostics li { margin: 0 0 12px; }
    #|@media (max-width: 820px) { main { width: min(100% - 20px, 1180px); padding-top: 20px; } .cards { grid-template-columns: repeat(2, minmax(0, 1fr)); } h1 { font-size: 28px; } }
    #|@media (max-width: 520px) { .cards { grid-template-columns: 1fr; } }
    #|</style>
  )
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
    "| Equivalent | \{report.equivalent} |",
    "| Score | \{report.score_percent}% |",
    "| Risk | \{mutation_risk_level(report)} |",
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
  lines.push("")
  lines.push("## Survived Diagnostics")
  lines.push("")
  for result in report.results {
    if result.outcome == Survived {
      let mutation = result.mutation
      let candidate = mutation.candidate
      lines.push(
        "- `#\{mutation.global_id}` \{mutation.file}:\{candidate.span.line} " +
        "\{candidate.rule.label}: \{escape_markdown_cell(diagnose_mutant_result(result))}",
      )
    }
  }
  if report.survived == 0 {
    lines.push("- none")
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
