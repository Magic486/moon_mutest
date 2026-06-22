///|
pub(all) struct MutationFilter {
  kinds : Array[MutationKind]
  labels : Array[String]
  line_start : Int?
  line_end : Int?
} derive(Debug, Eq, ToJson)

///|
pub fn MutationFilter::all() -> MutationFilter {
  { kinds: [], labels: [], line_start: None, line_end: None }
}

///|
pub fn MutationFilter::by_kind(kind : MutationKind) -> MutationFilter {
  { kinds: [kind], labels: [], line_start: None, line_end: None }
}

///|
pub fn MutationFilter::by_label(label : String) -> MutationFilter {
  { kinds: [], labels: [label], line_start: None, line_end: None }
}

///|
pub fn MutationFilter::lines(start~ : Int, end~ : Int) -> MutationFilter {
  { kinds: [], labels: [], line_start: Some(start), line_end: Some(end) }
}

///|
pub fn filter_candidates(
  candidates : ArrayView[MutationCandidate],
  filter : MutationFilter,
) -> Array[MutationCandidate] {
  let filtered : Array[MutationCandidate] = []
  for candidate in candidates {
    if matches_filter(candidate, filter) {
      filtered.push(candidate)
    }
  }
  filtered
}

///|
pub fn discover_filtered(
  source : String,
  filter : MutationFilter,
  file? : String = "<memory>",
) -> Array[MutationCandidate] {
  filter_candidates(discover(source, file~), filter)
}

///|
fn matches_filter(
  candidate : MutationCandidate,
  filter : MutationFilter,
) -> Bool {
  let kind_ok = filter.kinds.is_empty() ||
    filter.kinds.contains(candidate.rule.kind)
  let label_ok = filter.labels.is_empty() ||
    filter.labels.contains(candidate.rule.label)
  let start_ok = match filter.line_start {
    Some(start) => candidate.span.line >= start
    None => true
  }
  let end_ok = match filter.line_end {
    Some(end) => candidate.span.line <= end
    None => true
  }
  kind_ok && label_ok && start_ok && end_ok
}
