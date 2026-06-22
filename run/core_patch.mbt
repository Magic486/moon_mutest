///|
pub(all) struct TextEdit {
  file : String
  start : Int
  end : Int
  original : String
  replacement : String
  line : Int
  column : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PatchPreview {
  file : String
  line : Int
  before : String
  after : String
  diff : String
} derive(Debug, Eq, ToJson)

///|
pub fn edit_for_candidate(candidate : MutationCandidate) -> TextEdit {
  {
    file: candidate.span.file,
    start: candidate.span.start,
    end: candidate.span.end,
    original: candidate.original,
    replacement: candidate.replacement,
    line: candidate.span.line,
    column: candidate.span.column,
  }
}

///|
pub fn edit_for_project_mutation(mutation : ProjectMutation) -> TextEdit {
  edit_for_candidate(mutation.candidate)
}

///|
pub fn validate_edit(source : String, edit : TextEdit) -> Bool {
  edit.start >= 0 &&
  edit.end >= edit.start &&
  edit.end <= source.length() &&
  source[edit.start:edit.end].to_owned() == edit.original
}

///|
pub fn apply_edit(source : String, edit : TextEdit) -> String? {
  if validate_edit(source, edit) {
    Some(
      source[0:edit.start].to_owned() +
      edit.replacement +
      source[edit.end:source.length()].to_owned(),
    )
  } else {
    None
  }
}

///|
pub fn invert_edit(edit : TextEdit) -> TextEdit {
  {
    file: edit.file,
    start: edit.start,
    end: edit.start + edit.replacement.length(),
    original: edit.replacement,
    replacement: edit.original,
    line: edit.line,
    column: edit.column,
  }
}

///|
pub fn preview_candidate_patch(
  source : String,
  candidate : MutationCandidate,
) -> PatchPreview? {
  let edit = edit_for_candidate(candidate)
  match apply_edit(source, edit) {
    Some(mutated) => {
      let before = line_around(source, edit.start)
      let after = line_around(mutated, edit.start)
      Some({
        file: edit.file,
        line: edit.line,
        before,
        after,
        diff: format_unified_diff(edit.file, edit.line, before, after),
      })
    }
    None => None
  }
}

///|
pub fn format_unified_diff(
  file : String,
  line : Int,
  before : String,
  after : String,
) -> String {
  [
    "--- a/\{file}",
    "+++ b/\{file}",
    "@@ -\{line},1 +\{line},1 @@",
    "-\{before}",
    "+\{after}",
  ].join("\n")
}

///|
pub fn preview_project_mutation_patch(
  source : String,
  mutation : ProjectMutation,
) -> PatchPreview? {
  preview_candidate_patch(source, mutation.candidate)
}

///|
fn line_around(source : String, index : Int) -> String {
  let start = for i = index; i > 0; {
    if source[i - 1] == '\n' {
      break i
    } else {
      continue i - 1
    }
  } nobreak {
    0
  }
  let end = for i = index; i < source.length(); {
    if source[i] == '\n' {
      break i
    } else {
      continue i + 1
    }
  } nobreak {
    source.length()
  }
  source[start:end].to_owned()
}
