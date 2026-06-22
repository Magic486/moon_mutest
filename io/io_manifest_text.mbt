///|
pub fn format_candidate(candidate : MutationCandidate) -> String {
  "#\{candidate.id} " +
  "\{candidate.span.file}:\{candidate.span.line}:\{candidate.span.column} " +
  "\{candidate.rule.label} " +
  "\{candidate.original} -> \{candidate.replacement} | " +
  candidate.line_text
}

///|
pub fn format_candidate_list(
  candidates : ArrayView[MutationCandidate],
) -> String {
  if candidates.is_empty() {
    "No mutation candidates found."
  } else {
    [ for candidate in candidates => format_candidate(candidate) ].join("\n")
  }
}

///|
pub fn format_summary(summary : MutationSummary) -> String {
  [
    "Mutation candidates for \{summary.file}",
    "total: \{summary.candidate_count}",
    "boolean: \{summary.boolean_count}",
    "equality: \{summary.equality_count}",
    "relational: \{summary.relational_count}",
    "arithmetic: \{summary.arithmetic_count}",
    "logical: \{summary.logical_count}",
    "numeric: \{summary.numeric_count}",
  ].join("\n")
}

///|
pub fn format_manifest(source : String, file? : String = "<memory>") -> String {
  let candidates = discover(source, file~)
  let summary = summarize_candidates(file, candidates)
  format_summary(summary) + "\n\n" + format_candidate_list(candidates)
}

///|
pub fn format_manifest_with_profile(
  source : String,
  profile : RuleProfile,
  file? : String = "<memory>",
) -> String {
  let candidates = discover_with_profile(source, profile, file~)
  let summary = summarize_candidates(file, candidates)
  format_summary(summary) + "\n\n" + format_candidate_list(candidates)
}
