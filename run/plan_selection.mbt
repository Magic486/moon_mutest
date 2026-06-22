///|
pub(all) enum SelectionMode {
  AllMutants
  FirstMutants(Int)
  IdRange(start~ : Int, end~ : Int)
  Shard(shard_index~ : Int, shard_count~ : Int)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SelectionValidation {
  valid : Bool
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SelectionReport {
  mode : SelectionMode
  input_count : Int
  selected_count : Int
  skipped_count : Int
  selected_ids : Array[Int]
  valid : Bool
  message : String
} derive(Debug, Eq, ToJson)

///|
pub fn validate_selection_mode(mode : SelectionMode) -> SelectionValidation {
  match mode {
    AllMutants => { valid: true, message: "all mutants selected" }
    FirstMutants(limit) =>
      if limit >= 0 {
        { valid: true, message: "first \{limit} mutants selected" }
      } else {
        { valid: false, message: "first-mutants limit must be non-negative" }
      }
    IdRange(start~, end~) =>
      if start < 0 {
        { valid: false, message: "id range start must be non-negative" }
      } else if end < start {
        { valid: false, message: "id range end must be >= start" }
      } else {
        { valid: true, message: "ids \{start}..\{end} selected" }
      }
    Shard(shard_index~, shard_count~) =>
      if shard_count <= 0 {
        { valid: false, message: "shard count must be positive" }
      } else if shard_index < 0 || shard_index >= shard_count {
        { valid: false, message: "shard index must be in 0..\{shard_count}" }
      } else {
        {
          valid: true,
          message: "shard \{shard_index + 1}/\{shard_count} selected",
        }
      }
  }
}

///|
pub fn select_executions(
  plan : ExecutionPlan,
  mode : SelectionMode,
) -> Array[MutationExecution] {
  let selected : Array[MutationExecution] = []
  for index, execution in plan.executions {
    if matches_selection(execution.mutation.global_id, index, mode) {
      selected.push(execution)
    }
  }
  selected
}

///|
pub fn select_project_mutations(
  plan : ProjectMutationPlan,
  mode : SelectionMode,
) -> Array[ProjectMutation] {
  let selected : Array[ProjectMutation] = []
  for index, mutation in plan.mutations {
    if matches_selection(mutation.global_id, index, mode) {
      selected.push(mutation)
    }
  }
  selected
}

///|
pub fn summarize_execution_selection(
  plan : ExecutionPlan,
  mode : SelectionMode,
) -> SelectionReport {
  summarize_selected_ids(
    mode,
    input_count=plan.executions.length(),
    selected_ids=selected_execution_ids(plan, mode),
  )
}

///|
pub fn summarize_project_selection(
  plan : ProjectMutationPlan,
  mode : SelectionMode,
) -> SelectionReport {
  summarize_selected_ids(
    mode,
    input_count=plan.mutations.length(),
    selected_ids=selected_project_mutation_ids(plan, mode),
  )
}

///|
pub fn format_selection_mode(mode : SelectionMode) -> String {
  match mode {
    AllMutants => "all"
    FirstMutants(limit) => "first \{limit}"
    IdRange(start~, end~) => "ids \{start}..\{end}"
    Shard(shard_index~, shard_count~) =>
      "shard \{shard_index + 1}/\{shard_count}"
  }
}

///|
pub fn format_selection_report(report : SelectionReport) -> String {
  [
    "Mutation selection",
    "mode: \{format_selection_mode(report.mode)}",
    "valid: \{report.valid}",
    "input: \{report.input_count}",
    "selected: \{report.selected_count}",
    "skipped: \{report.skipped_count}",
    "ids: \{format_int_list(report.selected_ids)}",
    "message: \{report.message}",
  ].join("\n")
}

///|
fn summarize_selected_ids(
  mode : SelectionMode,
  input_count~ : Int,
  selected_ids~ : Array[Int],
) -> SelectionReport {
  let validation = validate_selection_mode(mode)
  {
    mode,
    input_count,
    selected_count: selected_ids.length(),
    skipped_count: input_count - selected_ids.length(),
    selected_ids,
    valid: validation.valid,
    message: validation.message,
  }
}

///|
fn selected_execution_ids(
  plan : ExecutionPlan,
  mode : SelectionMode,
) -> Array[Int] {
  let ids : Array[Int] = []
  for index, execution in plan.executions {
    let global_id = execution.mutation.global_id
    if matches_selection(global_id, index, mode) {
      ids.push(global_id)
    }
  }
  ids
}

///|
fn selected_project_mutation_ids(
  plan : ProjectMutationPlan,
  mode : SelectionMode,
) -> Array[Int] {
  let ids : Array[Int] = []
  for index, mutation in plan.mutations {
    if matches_selection(mutation.global_id, index, mode) {
      ids.push(mutation.global_id)
    }
  }
  ids
}

///|
fn matches_selection(
  global_id : Int,
  index : Int,
  mode : SelectionMode,
) -> Bool {
  match mode {
    AllMutants => true
    FirstMutants(limit) => limit >= 0 && index < limit
    IdRange(start~, end~) => start >= 0 && start <= global_id && global_id < end
    Shard(shard_index~, shard_count~) =>
      shard_count > 0 &&
      shard_index >= 0 &&
      shard_index < shard_count &&
      global_id % shard_count == shard_index
  }
}

///|
fn format_int_list(items : ArrayView[Int]) -> String {
  if items.is_empty() {
    "none"
  } else {
    [ for item in items => item.to_string() ].join(", ")
  }
}
