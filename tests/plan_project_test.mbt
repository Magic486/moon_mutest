///|
test "builds a project mutation plan across files" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("src/a.mbt", "let ok = a == b"),
    @moon_mutest.source_file("src/b.mbt", "let more = x + y && false"),
  ])
  inspect(plan.file_count, content="2")
  inspect(plan.mutation_count, content="4")
  inspect(plan.files[0].start_id, content="0")
  inspect(plan.files[0].end_id, content="1")
  inspect(plan.files[1].start_id, content="1")
  inspect(plan.files[1].end_id, content="4")
  inspect(plan.mutations[2].file, content="src/b.mbt")
  inspect(plan.mutations[2].global_id, content="2")
}

///|
test "project mutations keep mutated source" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("src/math.mbt", "let n = a + b"),
  ])
  match @moon_mutest.project_mutation_by_id(plan, 0) {
    Some(mutation) => {
      inspect(mutation.local_id, content="0")
      inspect(mutation.mutated_source, content="let n = a - b")
    }
    None => fail("expected mutation")
  }
  assert_true(@moon_mutest.project_mutation_by_id(plan, 5) is None)
}

///|
test "project planning supports filters" {
  let plan = @moon_mutest.plan_project_filtered(
    [
      @moon_mutest.source_file("src/a.mbt", "let ok = a == b && true"),
      @moon_mutest.source_file("src/b.mbt", "let n = a + b"),
    ],
    @moon_mutest.MutationFilter::by_kind(LogicalOperator),
  )
  inspect(plan.mutation_count, content="1")
  inspect(plan.mutations[0].candidate.rule.label, content="and-to-or")
}

///|
test "formats project plan" {
  let plan = @moon_mutest.plan_project([
    @moon_mutest.source_file("src/a.mbt", "a != b"),
    @moon_mutest.source_file("src/b.mbt", "false"),
  ])
  inspect(
    @moon_mutest.format_project_plan(plan),
    content=(
      #|Project mutation plan
      #|files: 2
      #|mutations: 2
      #|- src/a.mbt: 1 candidates (ids 0..1)
      #|- src/b.mbt: 1 candidates (ids 1..2)
      #|
      #|#0 src/a.mbt:1:3 ne-to-eq != -> ==
      #|#1 src/b.mbt:1:1 false-to-true false -> true
    ),
  )
}
