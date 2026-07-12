///|
test "runs mutations against a copied MoonBit workspace" {
  let stamp = @env.now().to_string()
  let fixture = join_path("_build", "moon-mutest-fixture-" + stamp)
  let temp = join_path("_build", "moon-mutest-run-" + stamp)
  if @fs.path_exists(fixture) {
    remove_workspace_tree(fixture)
  }
  if @fs.path_exists(temp) {
    remove_workspace_tree(temp)
  }
  ensure_dir(fixture)
  @fs.write_string_to_file(
    join_path(fixture, "moon.mod"),
    (
      #|name = "fixture/mut_target"
      #|version = "0.1.0"
      #|
    ),
  )
  @fs.write_string_to_file(join_path(fixture, "moon.pkg"), "")
  @fs.write_string_to_file(
    join_path(fixture, "lib.mbt"),
    (
      #|///|
      #|pub fn answer(x : Int) -> Bool {
      #|  x == 42
      #|}
      #|
    ),
  )
  @fs.write_string_to_file(
    join_path(fixture, "lib_test.mbt"),
    (
      #|///|
      #|test "answer recognizes 42" {
      #|  assert_true(answer(42))
      #|}
      #|
    ),
  )
  let config = { ..MutestConfig::default(), max_mutants: Some(1) }
  let report = run_workspace_mutations({
    ..WorkspaceRunnerOptions::default(fixture),
    temp_workspace: Some(temp),
    config,
    selection: FirstMutants(1),
    keep_temp: true,
  })
  inspect(report.baseline.can_run_mutants, content="true")
  inspect(report.selection.selected_count, content="1")
  inspect(report.report.killed, content="1")
  inspect(report.report.survived, content="0")
  inspect(@fs.path_exists(temp), content="true")
  remove_workspace_tree(fixture)
}

///|
test "parses changed files from Git output" {
  let paths = split_changed_file_lines("lib.mbt\r\ncmd\\main\\main.mbt\n\n")
  inspect(paths.length(), content="2")
  inspect(paths[0], content="lib.mbt")
  inspect(paths[1], content="cmd/main/main.mbt")
  inspect(is_safe_git_reference("origin/master~1"), content="true")
  inspect(is_safe_git_reference("HEAD; rm -rf /"), content="false")
  inspect(first_nonempty_output_line("\r\nabc123\n"), content="abc123")
}

///|
test "Git incremental selection uses merge base and includes working changes" {
  let stamp = @env.now().to_string()
  let fixture = join_path("_build", "moon-mutest-git-fixture-" + stamp)
  ensure_dir(fixture)
  @fs.write_string_to_file(join_path(fixture, "lib.mbt"), "let value = 1\n")
  assert_true(
    execute_shell_command("git init -q", fixture, 10000).exit_code == 0,
  )
  assert_true(
    execute_shell_command(
      "git config user.email test@example.com", fixture, 10000,
    ).exit_code ==
    0,
  )
  assert_true(
    execute_shell_command(
      "git config user.name moon-mutest-test", fixture, 10000,
    ).exit_code ==
    0,
  )
  assert_true(
    execute_shell_command("git add lib.mbt", fixture, 10000).exit_code == 0,
  )
  assert_true(
    execute_shell_command("git commit -qm base", fixture, 10000).exit_code == 0,
  )
  inspect(changed_workspace_files_since(fixture, "HEAD").length(), content="0")
  @fs.write_string_to_file(join_path(fixture, "lib.mbt"), "let value = 2\n")
  let changed = changed_workspace_files_since(fixture, "HEAD")
  inspect(changed.length(), content="1")
  inspect(changed[0], content="lib.mbt")
  remove_workspace_tree(fixture)
}

///|
test "records manually reviewed equivalent mutants without executing them" {
  let stamp = @env.now().to_string()
  let fixture = join_path("_build", "moon-mutest-equivalent-" + stamp)
  let temp = join_path("_build", "moon-mutest-equivalent-run-" + stamp)
  ensure_dir(fixture)
  @fs.write_string_to_file(
    join_path(fixture, "moon.mod"),
    "name = \"fixture/equivalent_target\"\nversion = \"0.1.0\"\n",
  )
  @fs.write_string_to_file(join_path(fixture, "moon.pkg"), "")
  @fs.write_string_to_file(
    join_path(fixture, "lib.mbt"),
    "pub fn answer(x : Int) -> Bool { x == 42 }\n",
  )
  @fs.write_string_to_file(
    join_path(fixture, "lib_test.mbt"),
    "test \"answer\" { assert_true(answer(42)) }\n",
  )
  let report = run_workspace_mutations({
    ..WorkspaceRunnerOptions::default(fixture),
    temp_workspace: Some(temp),
    config: { ..MutestConfig::default(), max_mutants: Some(1) },
    selection: FirstMutants(1),
    equivalent_mutants: [{ id: 0, reason: "reviewed compatibility branch" }],
  })
  inspect(report.report.equivalent, content="1")
  inspect(report.report.killed, content="0")
  inspect(
    report.report.results[0].detail,
    content="reviewed compatibility branch",
  )
  remove_workspace_tree(fixture)
}
