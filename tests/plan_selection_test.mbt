///|
fn sample_selection_plan() -> @moon_mutest.ExecutionPlan {
  let config = @moon_mutest.MutestConfig::default()
  @moon_mutest.build_execution_plan(
    [
      @moon_mutest.source_file("src/a.mbt", "a == b && false"),
      @moon_mutest.source_file("src/b.mbt", "x + y || true"),
    ],
    config,
  )
}

///|
test "selection can keep all executions" {
  let plan = sample_selection_plan()
  let selected = @moon_mutest.select_executions(plan, AllMutants)
  inspect(plan.executions.length(), content="6")
  inspect(selected.length(), content="6")
  inspect(selected[5].mutation.global_id, content="5")
}

///|
test "selection can keep first n executions" {
  let plan = sample_selection_plan()
  let selected = @moon_mutest.select_executions(plan, FirstMutants(2))
  inspect(selected.length(), content="2")
  inspect(selected[0].mutation.global_id, content="0")
  inspect(selected[1].mutation.global_id, content="1")
}

///|
test "selection uses half-open id ranges" {
  let plan = sample_selection_plan()
  let selected = @moon_mutest.select_executions(plan, IdRange(start=2, end=5))
  inspect(selected.length(), content="3")
  inspect(selected[0].mutation.global_id, content="2")
  inspect(selected[2].mutation.global_id, content="4")
}

///|
test "selection shards by stable global ids" {
  let plan = sample_selection_plan()
  let selected = @moon_mutest.select_executions(
    plan,
    Shard(shard_index=1, shard_count=3),
  )
  inspect(selected.length(), content="2")
  inspect(selected[0].mutation.global_id, content="1")
  inspect(selected[1].mutation.global_id, content="4")
}

///|
test "selection reports invalid modes without selecting surprise mutants" {
  let plan = sample_selection_plan()
  let selected = @moon_mutest.select_executions(
    plan,
    Shard(shard_index=0, shard_count=0),
  )
  let report = @moon_mutest.summarize_execution_selection(
    plan,
    Shard(shard_index=0, shard_count=0),
  )
  inspect(selected.length(), content="0")
  inspect(report.valid, content="false")
  inspect(report.message, content="shard count must be positive")
}

///|
test "selection can operate on project mutations before execution planning" {
  let project = @moon_mutest.plan_project([
    @moon_mutest.source_file("a.mbt", "a != b"),
    @moon_mutest.source_file("b.mbt", "a >= b && true"),
  ])
  let selected = @moon_mutest.select_project_mutations(
    project,
    IdRange(start=1, end=3),
  )
  inspect(project.mutation_count, content="4")
  inspect(selected.length(), content="2")
  inspect(selected[0].global_id, content="1")
  inspect(selected[1].global_id, content="2")
}

///|
test "formats selection reports" {
  let report = @moon_mutest.summarize_execution_selection(
    sample_selection_plan(),
    FirstMutants(3),
  )
  inspect(
    @moon_mutest.format_selection_report(report),
    content=(
      #|Mutation selection
      #|mode: first 3
      #|valid: true
      #|input: 6
      #|selected: 3
      #|skipped: 3
      #|ids: 0, 1, 2
      #|message: first 3 mutants selected
    ),
  )
}
