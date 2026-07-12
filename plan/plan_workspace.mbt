///|
pub(all) enum WorkspaceFileCategory {
  SourceFileCategory
  TestFileCategory
  GeneratedFileCategory
  ExcludedFileCategory
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkspaceFileSpec {
  include_suffixes : Array[String]
  exclude_segments : Array[String]
  exclude_suffixes : Array[String]
  include_tests : Bool
  include_generated : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkspaceFileDecision {
  path : String
  included : Bool
  category : WorkspaceFileCategory
  reason : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkspaceSelectionReport {
  total_files : Int
  included_files : Int
  excluded_files : Int
  source_files : Int
  test_files : Int
  generated_files : Int
  decisions : Array[WorkspaceFileDecision]
} derive(Debug, Eq, ToJson)

///|
pub fn WorkspaceFileSpec::moonbit_default() -> WorkspaceFileSpec {
  {
    include_suffixes: [".mbt"],
    exclude_segments: ["_build", ".moon", ".git", ".repos"],
    exclude_suffixes: [],
    include_tests: false,
    include_generated: false,
  }
}

///|
pub fn WorkspaceFileSpec::with_tests() -> WorkspaceFileSpec {
  {
    include_suffixes: [".mbt"],
    exclude_segments: ["_build", ".moon", ".git", ".repos"],
    exclude_suffixes: [],
    include_tests: true,
    include_generated: false,
  }
}

///|
pub fn classify_workspace_file(
  path : String,
  spec : WorkspaceFileSpec,
) -> WorkspaceFileDecision {
  if !has_any_suffix(path, spec.include_suffixes) {
    {
      path,
      included: false,
      category: ExcludedFileCategory,
      reason: "path does not match included suffixes",
    }
  } else if has_any_segment(path, spec.exclude_segments) {
    {
      path,
      included: false,
      category: ExcludedFileCategory,
      reason: "path is under an excluded directory",
    }
  } else if is_generated_moonbit_path(path) {
    {
      path,
      included: spec.include_generated,
      category: GeneratedFileCategory,
      reason: if spec.include_generated {
        "generated MoonBit file included by configuration"
      } else {
        "generated MoonBit file excluded by default"
      },
    }
  } else if has_any_suffix(path, spec.exclude_suffixes) {
    {
      path,
      included: false,
      category: ExcludedFileCategory,
      reason: "path matches an excluded suffix",
    }
  } else if is_test_moonbit_path(path) {
    {
      path,
      included: spec.include_tests,
      category: TestFileCategory,
      reason: if spec.include_tests {
        "test file included by configuration"
      } else {
        "test file excluded by default"
      },
    }
  } else {
    {
      path,
      included: true,
      category: SourceFileCategory,
      reason: "MoonBit source file included",
    }
  }
}

///|
pub fn select_workspace_files(
  files : ArrayView[SourceFile],
  spec : WorkspaceFileSpec,
) -> Array[SourceFile] {
  let selected : Array[SourceFile] = []
  for file in files {
    let decision = classify_workspace_file(file.path, spec)
    if decision.included {
      selected.push(file)
    }
  }
  selected
}

///|
/// Keep only already-selected workspace files whose root-relative paths are
/// present in a Git changed-file list.
pub fn select_changed_workspace_files(
  files : ArrayView[SourceFile],
  changed_paths : ArrayView[String],
) -> Array[SourceFile] {
  let selected : Array[SourceFile] = []
  for file in files {
    if is_changed_workspace_path(file.path, changed_paths) {
      selected.push(file)
    }
  }
  selected
}

///|
pub fn summarize_workspace_selection(
  files : ArrayView[SourceFile],
  spec : WorkspaceFileSpec,
) -> WorkspaceSelectionReport {
  let decisions : Array[WorkspaceFileDecision] = []
  let mut included_files = 0
  let mut source_files = 0
  let mut test_files = 0
  let mut generated_files = 0
  for file in files {
    let decision = classify_workspace_file(file.path, spec)
    if decision.included {
      included_files += 1
      match decision.category {
        SourceFileCategory => source_files += 1
        TestFileCategory => test_files += 1
        GeneratedFileCategory => generated_files += 1
        ExcludedFileCategory => ()
      }
    }
    decisions.push(decision)
  }
  {
    total_files: files.length(),
    included_files,
    excluded_files: files.length() - included_files,
    source_files,
    test_files,
    generated_files,
    decisions,
  }
}

///|
pub fn format_workspace_file_category(
  category : WorkspaceFileCategory,
) -> String {
  match category {
    SourceFileCategory => "source"
    TestFileCategory => "test"
    GeneratedFileCategory => "generated"
    ExcludedFileCategory => "excluded"
  }
}

///|
pub fn format_workspace_selection_report(
  report : WorkspaceSelectionReport,
) -> String {
  let lines : Array[String] = [
    "Workspace selection",
    "total-files: \{report.total_files}",
    "included-files: \{report.included_files}",
    "excluded-files: \{report.excluded_files}",
    "source-files: \{report.source_files}",
    "test-files: \{report.test_files}",
    "generated-files: \{report.generated_files}",
  ]
  for decision in report.decisions {
    let action = if decision.included { "include" } else { "exclude" }
    lines.push(
      "- \{decision.path}: " +
      "\{action} " +
      "(\{format_workspace_file_category(decision.category)}) " +
      "\{decision.reason}",
    )
  }
  lines.join("\n")
}

///|
fn has_any_suffix(path : String, suffixes : ArrayView[String]) -> Bool {
  for suffix in suffixes {
    if path.has_suffix(suffix) {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn has_any_segment(path : String, segments : ArrayView[String]) -> Bool {
  let normalized = normalize_path(path)
  for segment in segments {
    if normalized == segment ||
      normalized.has_prefix(segment + "/") ||
      normalized.has_suffix("/" + segment) ||
      normalized.contains("/" + segment + "/") {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn is_test_moonbit_path(path : String) -> Bool {
  path.has_suffix("_test.mbt") ||
  path.has_suffix("_wbtest.mbt") ||
  normalize_path(path).contains("/test/")
}

///|
fn is_generated_moonbit_path(path : String) -> Bool {
  path.has_suffix(".generated.mbt") ||
  path.has_suffix(".generated.mbti") ||
  path.has_suffix("pkg.generated.mbti")
}

///|
fn normalize_path(path : String) -> String {
  path.replace(old="\\", new="/")
}

///|
fn is_changed_workspace_path(
  file_path : String,
  changed_paths : ArrayView[String],
) -> Bool {
  let normalized_file = normalize_path(file_path)
  for changed_path in changed_paths {
    if normalized_file == normalize_path(changed_path) {
      break true
    }
  } nobreak {
    false
  }
}
