///|
pub(all) struct MutationExecution {
  mutation : ProjectMutation
  edit : TextEdit
  restore_edit : TextEdit
  commands : Array[RunnerCommand]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ExecutionPlan {
  config : MutestConfig
  project : ProjectMutationPlan
  executions : Array[MutationExecution]
  truncated : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn build_execution_plan(
  files : ArrayView[SourceFile],
  config : MutestConfig,
) -> ExecutionPlan {
  build_execution_plan_with_profile(files, config, BasicProfile)
}

///|
pub fn build_execution_plan_with_profile(
  files : ArrayView[SourceFile],
  config : MutestConfig,
  profile : RuleProfile,
) -> ExecutionPlan {
  let project = plan_project_with_rules(
    files,
    config.to_filter(),
    rules_for_profile(profile),
  )
  let executions : Array[MutationExecution] = []
  let limit = config.max_mutants
  for mutation in project.mutations {
    if within_execution_limit(executions.length(), limit) {
      let edit = edit_for_project_mutation(mutation)
      executions.push({
        mutation,
        edit,
        restore_edit: invert_edit(edit),
        commands: config.commands,
      })
    }
  }
  {
    config,
    project,
    executions,
    truncated: match limit {
      Some(max) => project.mutations.length() > max
      None => false
    },
  }
}

///|
pub fn plan_project_with_rules(
  files : ArrayView[SourceFile],
  filter : MutationFilter,
  rules : ArrayView[MutationRule],
) -> ProjectMutationPlan {
  let file_plans : Array[FileMutationPlan] = []
  let mutations : Array[ProjectMutation] = []
  let mut next_id = 0
  for file_index, source in files {
    let raw_candidates = discover_with_rules(
      source.content,
      rules,
      file=source.path,
    )
    let candidates = filter_candidates(raw_candidates, filter)
    let start_id = next_id
    for candidate in candidates {
      mutations.push({
        global_id: next_id,
        file_index,
        file: source.path,
        local_id: candidate.id,
        candidate,
        mutated_source: apply_mutation(source.content, candidate),
      })
      next_id += 1
    }
    file_plans.push({
      file: source.path,
      file_index,
      start_id,
      end_id: next_id,
      summary: summarize_candidates(source.path, candidates),
      candidates,
    })
  }
  {
    file_count: files.length(),
    mutation_count: mutations.length(),
    files: file_plans,
    mutations,
  }
}

///|
pub fn format_execution_plan(plan : ExecutionPlan) -> String {
  let lines : Array[String] = [
    "Mutation execution plan",
    "files: \{plan.project.file_count}",
    "mutations: \{plan.project.mutation_count}",
    "executions: \{plan.executions.length()}",
    "truncated: \{plan.truncated}",
    "commands:",
  ]
  for command in plan.config.commands {
    lines.push("- " + format_runner_command(command))
  }
  lines.push("")
  lines.push("mutants:")
  for execution in plan.executions {
    let mutation = execution.mutation
    lines.push(
      "- #\{mutation.global_id} \{mutation.file}:" +
      "\{mutation.candidate.span.line} \{mutation.candidate.rule.label}",
    )
  }
  lines.join("\n")
}

///|
pub fn execution_by_mutation_id(
  plan : ExecutionPlan,
  global_id : Int,
) -> MutationExecution? {
  for execution in plan.executions {
    if execution.mutation.global_id == global_id {
      break Some(execution)
    }
  } nobreak {
    None
  }
}

///|
fn within_execution_limit(count : Int, limit : Int?) -> Bool {
  match limit {
    Some(max) => count < max
    None => true
  }
}
