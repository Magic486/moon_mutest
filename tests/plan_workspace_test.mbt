///|
fn workspace_files() -> Array[@moon_mutest.SourceFile] {
  [
    @moon_mutest.source_file("src/lib.mbt", "a == b"),
    @moon_mutest.source_file("src/lib_test.mbt", "test {}"),
    @moon_mutest.source_file("src/generated.generated.mbt", "let x = 1"),
    @moon_mutest.source_file("_build/gen/out.mbt", "let y = 2"),
    @moon_mutest.source_file("README.md", "# docs"),
    @moon_mutest.source_file("cmd/main/main.mbt", "fn main {}"),
  ]
}

///|
test "workspace default selects production MoonBit sources" {
  let spec = @moon_mutest.WorkspaceFileSpec::moonbit_default()
  let selected = @moon_mutest.select_workspace_files(workspace_files(), spec)
  inspect(selected.length(), content="2")
  inspect(selected[0].path, content="src/lib.mbt")
  inspect(selected[1].path, content="cmd/main/main.mbt")
}

///|
test "workspace spec can include test files" {
  let selected = @moon_mutest.select_workspace_files(
    workspace_files(),
    @moon_mutest.WorkspaceFileSpec::with_tests(),
  )
  inspect(selected.length(), content="3")
  inspect(selected[1].path, content="src/lib_test.mbt")
}

///|
test "workspace selection can keep only Git-changed production files" {
  let selected = @moon_mutest.select_changed_workspace_files(
    @moon_mutest.select_workspace_files(
      workspace_files(),
      @moon_mutest.WorkspaceFileSpec::moonbit_default(),
    ),
    ["cmd/main/main.mbt", "src/lib_test.mbt", "README.md"],
  )
  inspect(selected.length(), content="1")
  inspect(selected[0].path, content="cmd/main/main.mbt")
}

///|
test "workspace file classification explains decisions" {
  let spec = @moon_mutest.WorkspaceFileSpec::moonbit_default()
  let test_decision = @moon_mutest.classify_workspace_file(
    "src/lib_test.mbt", spec,
  )
  let generated_decision = @moon_mutest.classify_workspace_file(
    "src/generated.generated.mbt", spec,
  )
  let build_decision = @moon_mutest.classify_workspace_file(
    "_build/gen/out.mbt", spec,
  )
  inspect(test_decision.included, content="false")
  debug_inspect(test_decision.category, content="TestFileCategory")
  inspect(test_decision.reason, content="test file excluded by default")
  debug_inspect(generated_decision.category, content="GeneratedFileCategory")
  inspect(
    generated_decision.reason,
    content="generated MoonBit file excluded by default",
  )
  inspect(build_decision.reason, content="path is under an excluded directory")
}

///|
test "workspace report counts included categories" {
  let report = @moon_mutest.summarize_workspace_selection(
    workspace_files(),
    @moon_mutest.WorkspaceFileSpec::with_tests(),
  )
  inspect(report.total_files, content="6")
  inspect(report.included_files, content="3")
  inspect(report.excluded_files, content="3")
  inspect(report.source_files, content="2")
  inspect(report.test_files, content="1")
  inspect(report.generated_files, content="0")
}

///|
test "workspace report formatting is stable" {
  let report = @moon_mutest.summarize_workspace_selection(
    [
      @moon_mutest.source_file("src/lib.mbt", "a == b"),
      @moon_mutest.source_file("src/lib_test.mbt", "test {}"),
    ],
    @moon_mutest.WorkspaceFileSpec::moonbit_default(),
  )
  inspect(
    @moon_mutest.format_workspace_selection_report(report),
    content=(
      #|Workspace selection
      #|total-files: 2
      #|included-files: 1
      #|excluded-files: 1
      #|source-files: 1
      #|test-files: 0
      #|generated-files: 0
      #|- src/lib.mbt: include (source) MoonBit source file included
      #|- src/lib_test.mbt: exclude (test) test file excluded by default
    ),
  )
}
