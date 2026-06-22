///|
pub(all) enum BatchStrategy {
  OneMutantPerBatch
  FixedBatchSize(Int)
  TargetBatchMillis(Int)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BatchValidation {
  valid : Bool
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ExecutionBatch {
  batch_id : Int
  start_index : Int
  end_index : Int
  execution_count : Int
  command_count : Int
  estimated_timeout_ms : Int
  executions : Array[MutationExecution]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BatchPlan {
  strategy : BatchStrategy
  selection : SelectionMode
  batch_count : Int
  execution_count : Int
  command_count : Int
  estimated_timeout_ms : Int
  valid : Bool
  message : String
  batches : Array[ExecutionBatch]
} derive(Debug, Eq, ToJson)

///|
pub fn validate_batch_strategy(strategy : BatchStrategy) -> BatchValidation {
  match strategy {
    OneMutantPerBatch => { valid: true, message: "one mutant per batch" }
    FixedBatchSize(size) =>
      if size > 0 {
        { valid: true, message: "fixed batch size \{size}" }
      } else {
        { valid: false, message: "batch size must be positive" }
      }
    TargetBatchMillis(ms) =>
      if ms > 0 {
        { valid: true, message: "target batch budget \{ms} ms" }
      } else {
        { valid: false, message: "target batch millis must be positive" }
      }
  }
}

///|
pub fn build_batch_plan(
  plan : ExecutionPlan,
  strategy : BatchStrategy,
) -> BatchPlan {
  build_selected_batch_plan(plan, AllMutants, strategy)
}

///|
pub fn build_selected_batch_plan(
  plan : ExecutionPlan,
  selection : SelectionMode,
  strategy : BatchStrategy,
) -> BatchPlan {
  let executions = select_executions(plan, selection)
  let validation = validate_batch_strategy(strategy)
  if validation.valid {
    let batches = batches_for_strategy(executions, strategy)
    summarize_batches(strategy, selection, validation, batches)
  } else {
    summarize_batches(strategy, selection, validation, [])
  }
}

///|
pub fn estimate_execution_timeout_ms(execution : MutationExecution) -> Int {
  let mut total = 0
  for command in execution.commands {
    total += command.timeout_ms
  }
  total
}

///|
pub fn format_batch_strategy(strategy : BatchStrategy) -> String {
  match strategy {
    OneMutantPerBatch => "one-mutant"
    FixedBatchSize(size) => "fixed-size \{size}"
    TargetBatchMillis(ms) => "target-ms \{ms}"
  }
}

///|
pub fn format_batch_plan(plan : BatchPlan) -> String {
  let lines : Array[String] = [
    "Mutation batch plan",
    "strategy: \{format_batch_strategy(plan.strategy)}",
    "selection: \{format_selection_mode(plan.selection)}",
    "valid: \{plan.valid}",
    "batches: \{plan.batch_count}",
    "executions: \{plan.execution_count}",
    "commands: \{plan.command_count}",
    "estimated-timeout-ms: \{plan.estimated_timeout_ms}",
    "message: \{plan.message}",
  ]
  for batch in plan.batches {
    lines.push(
      "- batch #\{batch.batch_id}: executions " +
      "\{batch.start_index}..\{batch.end_index}, " +
      "mutants=\{batch.execution_count}, " +
      "commands=\{batch.command_count}, " +
      "timeout-ms=\{batch.estimated_timeout_ms}",
    )
  }
  lines.join("\n")
}

///|
fn batches_for_strategy(
  executions : ArrayView[MutationExecution],
  strategy : BatchStrategy,
) -> Array[ExecutionBatch] {
  match strategy {
    OneMutantPerBatch => batches_by_size(executions, 1)
    FixedBatchSize(size) => batches_by_size(executions, size)
    TargetBatchMillis(ms) => batches_by_timeout(executions, ms)
  }
}

///|
fn batches_by_size(
  executions : ArrayView[MutationExecution],
  size : Int,
) -> Array[ExecutionBatch] {
  let batches : Array[ExecutionBatch] = []
  let mut current : Array[MutationExecution] = []
  let mut start_index = 0
  for index, execution in executions {
    if current.is_empty() {
      start_index = index
    }
    current.push(execution)
    if current.length() == size {
      batches.push(
        make_batch(batches.length(), start_index, index + 1, current),
      )
      current = []
    }
  }
  if !current.is_empty() {
    batches.push(
      make_batch(
        batches.length(),
        start_index,
        start_index + current.length(),
        current,
      ),
    )
  }
  batches
}

///|
fn batches_by_timeout(
  executions : ArrayView[MutationExecution],
  target_ms : Int,
) -> Array[ExecutionBatch] {
  let batches : Array[ExecutionBatch] = []
  let mut current : Array[MutationExecution] = []
  let mut current_ms = 0
  let mut start_index = 0
  for index, execution in executions {
    let next_ms = estimate_execution_timeout_ms(execution)
    if current.is_empty() {
      start_index = index
      current.push(execution)
      current_ms = next_ms
    } else if current_ms + next_ms > target_ms {
      batches.push(make_batch(batches.length(), start_index, index, current))
      current = [execution]
      current_ms = next_ms
      start_index = index
    } else {
      current.push(execution)
      current_ms += next_ms
    }
  }
  if !current.is_empty() {
    batches.push(
      make_batch(
        batches.length(),
        start_index,
        start_index + current.length(),
        current,
      ),
    )
  }
  batches
}

///|
fn make_batch(
  batch_id : Int,
  start_index : Int,
  end_index : Int,
  executions : Array[MutationExecution],
) -> ExecutionBatch {
  let mut command_count = 0
  let mut estimated_timeout_ms = 0
  for execution in executions {
    command_count += execution.commands.length()
    estimated_timeout_ms += estimate_execution_timeout_ms(execution)
  }
  {
    batch_id,
    start_index,
    end_index,
    execution_count: executions.length(),
    command_count,
    estimated_timeout_ms,
    executions,
  }
}

///|
fn summarize_batches(
  strategy : BatchStrategy,
  selection : SelectionMode,
  validation : BatchValidation,
  batches : Array[ExecutionBatch],
) -> BatchPlan {
  let mut execution_count = 0
  let mut command_count = 0
  let mut estimated_timeout_ms = 0
  for batch in batches {
    execution_count += batch.execution_count
    command_count += batch.command_count
    estimated_timeout_ms += batch.estimated_timeout_ms
  }
  {
    strategy,
    selection,
    batch_count: batches.length(),
    execution_count,
    command_count,
    estimated_timeout_ms,
    valid: validation.valid,
    message: validation.message,
    batches,
  }
}
