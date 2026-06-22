///|
fn batch_config() -> @moon_mutest.MutestConfig {
  {
    include_kinds: [],
    include_labels: [],
    line_start: None,
    line_end: None,
    max_mutants: None,
    commands: [
      { phase: CheckPhase, command: "moon check", timeout_ms: 10 },
      { phase: TestPhase, command: "moon test", timeout_ms: 20 },
    ],
    fail_fast: true,
    report_format: TextReport,
  }
}

///|
fn batch_plan_source() -> @moon_mutest.ExecutionPlan {
  @moon_mutest.build_execution_plan(
    [
      @moon_mutest.source_file("a.mbt", "a == b && false"),
      @moon_mutest.source_file("b.mbt", "x + y"),
    ],
    batch_config(),
  )
}

///|
test "estimates timeout budget for an execution" {
  let plan = batch_plan_source()
  inspect(plan.executions.length(), content="4")
  inspect(
    @moon_mutest.estimate_execution_timeout_ms(plan.executions[0]),
    content="30",
  )
}

///|
test "builds fixed-size batch plans" {
  let batches = @moon_mutest.build_batch_plan(
    batch_plan_source(),
    FixedBatchSize(2),
  )
  inspect(batches.valid, content="true")
  inspect(batches.batch_count, content="2")
  inspect(batches.execution_count, content="4")
  inspect(batches.command_count, content="8")
  inspect(batches.estimated_timeout_ms, content="120")
  inspect(batches.batches[1].start_index, content="2")
  inspect(batches.batches[1].end_index, content="4")
}

///|
test "builds timeout-budget batch plans" {
  let batches = @moon_mutest.build_batch_plan(
    batch_plan_source(),
    TargetBatchMillis(60),
  )
  inspect(batches.batch_count, content="2")
  inspect(batches.batches[0].execution_count, content="2")
  inspect(batches.batches[0].estimated_timeout_ms, content="60")
  inspect(batches.batches[1].execution_count, content="2")
}

///|
test "batch planning can apply mutation selection first" {
  let batches = @moon_mutest.build_selected_batch_plan(
    batch_plan_source(),
    Shard(shard_index=1, shard_count=2),
    OneMutantPerBatch,
  )
  inspect(
    @moon_mutest.format_selection_mode(batches.selection),
    content="shard 2/2",
  )
  inspect(batches.execution_count, content="2")
  inspect(batches.batch_count, content="2")
  inspect(batches.batches[0].executions[0].mutation.global_id, content="1")
}

///|
test "invalid batch strategies produce empty invalid plans" {
  let batches = @moon_mutest.build_batch_plan(
    batch_plan_source(),
    FixedBatchSize(0),
  )
  inspect(batches.valid, content="false")
  inspect(batches.batch_count, content="0")
  inspect(batches.execution_count, content="0")
  inspect(batches.message, content="batch size must be positive")
}

///|
test "formats batch plans" {
  let batches = @moon_mutest.build_batch_plan(
    batch_plan_source(),
    FixedBatchSize(3),
  )
  inspect(
    @moon_mutest.format_batch_plan(batches),
    content=(
      #|Mutation batch plan
      #|strategy: fixed-size 3
      #|selection: all
      #|valid: true
      #|batches: 2
      #|executions: 4
      #|commands: 8
      #|estimated-timeout-ms: 120
      #|message: fixed batch size 3
      #|- batch #0: executions 0..3, mutants=3, commands=6, timeout-ms=90
      #|- batch #1: executions 3..4, mutants=1, commands=2, timeout-ms=30
    ),
  )
}
