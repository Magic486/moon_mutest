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
  })
  inspect(report.baseline.can_run_mutants, content="true")
  inspect(report.selection.selected_count, content="1")
  inspect(report.report.killed, content="1")
  inspect(report.report.survived, content="0")
  inspect(@fs.path_exists(temp), content="false")
  remove_workspace_tree(fixture)
}
