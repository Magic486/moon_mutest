///|
pub(all) struct WorkspaceRunnerOptions {
  workspace : String
  temp_workspace : String?
  file_spec : WorkspaceFileSpec
  profile : RuleProfile
  config : MutestConfig
  selection : SelectionMode
  keep_temp : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkspaceRunReport {
  workspace : String
  temp_workspace : String
  kept_temp : Bool
  snapshot : WorkspaceSnapshot
  plan : ExecutionPlan
  selection : SelectionReport
  baseline_commands : Array[CommandResult]
  baseline : BaselineReport
  report : ProjectRunReport
} derive(Debug, Eq, ToJson)

///|
pub fn WorkspaceRunnerOptions::default(
  workspace : String,
) -> WorkspaceRunnerOptions {
  {
    workspace,
    temp_workspace: None,
    file_spec: WorkspaceFileSpec::moonbit_default(),
    profile: BasicProfile,
    config: MutestConfig::default(),
    selection: AllMutants,
    keep_temp: false,
  }
}

///|
pub fn run_workspace_mutations(
  options : WorkspaceRunnerOptions,
) -> WorkspaceRunReport raise {
  let snapshot = load_workspace_snapshot(options.workspace, options.file_spec)
  let temp_workspace = match options.temp_workspace {
    Some(path) => node_path_resolve(path)
    None => default_temp_workspace(snapshot.root)
  }
  copy_workspace_for_mutation(snapshot.root, temp_workspace)
  let plan = build_execution_plan_with_profile(
    snapshot.selected_files,
    options.config,
    options.profile,
  )
  let selection = summarize_execution_selection(plan, options.selection)
  let baseline_commands = run_baseline_commands(
    temp_workspace,
    plan.config.commands,
  )
  let baseline = classify_baseline(plan.config.commands, baseline_commands)
  let results = if baseline.can_run_mutants {
    run_selected_mutants(temp_workspace, plan, options.selection)
  } else {
    skip_selected_results_for_baseline(plan, options.selection, baseline)
  }
  let report = summarize_project_run(plan.project, results)
  if !options.keep_temp {
    remove_workspace_tree(temp_workspace)
  }
  {
    workspace: snapshot.root,
    temp_workspace,
    kept_temp: options.keep_temp,
    snapshot,
    plan,
    selection,
    baseline_commands,
    baseline,
    report,
  }
}

///|
pub fn format_workspace_run_report(report : WorkspaceRunReport) -> String {
  [
    "Workspace mutation run",
    "workspace: \{report.workspace}",
    "temp-workspace: \{report.temp_workspace}",
    "kept-temp: \{report.kept_temp}",
    "files: \{report.snapshot.selection.included_files}/\{report.snapshot.selection.total_files}",
    "planned-mutants: \{report.plan.project.mutation_count}",
    "selected-mutants: \{report.selection.selected_count}",
    "baseline: \{baseline_outcome_label(report.baseline.outcome)}",
    "executed-results: \{report.report.results.length()}",
    "killed: \{report.report.killed}",
    "survived: \{report.report.survived}",
    "compile-error: \{report.report.compile_error}",
    "timeout: \{report.report.timeout}",
    "skipped: \{report.report.skipped}",
    "score: \{report.report.score_percent}%",
    "detail: \{report.baseline.detail}",
  ].join("\n")
}

///|
pub fn workspace_run_report_to_json(
  report : WorkspaceRunReport,
  indent? : Int = 2,
) -> String {
  report.to_json().stringify(indent~)
}

///|
fn run_baseline_commands(
  workspace : String,
  commands : ArrayView[RunnerCommand],
) -> Array[CommandResult] {
  let results : Array[CommandResult] = []
  for command in commands {
    let result = execute_runner_command(workspace, command)
    results.push(result)
    if result.timed_out || result.exit_code != Some(0) {
      break
    }
  }
  results
}

///|
fn run_selected_mutants(
  workspace : String,
  plan : ExecutionPlan,
  mode : SelectionMode,
) -> Array[ProjectMutantResult] raise {
  let results : Array[ProjectMutantResult] = []
  for execution in select_executions(plan, mode) {
    results.push(run_one_mutant(workspace, execution, plan.config))
  }
  results
}

///|
fn run_one_mutant(
  workspace : String,
  execution : MutationExecution,
  config : MutestConfig,
) -> ProjectMutantResult raise {
  let target = workspace_file(workspace, execution.mutation.file)
  let original = @fs.read_file_to_string(target)
  match apply_edit(original, execution.edit) {
    Some(mutated) => {
      @fs.write_string_to_file(target, mutated)
      let commands = run_mutant_commands(
        workspace,
        execution.commands,
        execution.mutation,
        config.fail_fast,
      )
      @fs.write_string_to_file(target, original)
      classify_project_sequence(execution.mutation, commands)
    }
    None =>
      project_result(
        execution.mutation,
        Skipped,
        detail="mutation edit no longer matches copied workspace file",
      )
  }
}

///|
fn run_mutant_commands(
  workspace : String,
  commands : ArrayView[RunnerCommand],
  mutation : ProjectMutation,
  fail_fast : Bool,
) -> Array[CommandResult] {
  let results : Array[CommandResult] = []
  for command in commands {
    let result = execute_runner_command(workspace, command)
    results.push(result)
    let signal = classify_command_result(mutation.candidate, result)
    if fail_fast && signal.outcome != Survived {
      break
    }
  }
  results
}

///|
fn execute_runner_command(
  workspace : String,
  command : RunnerCommand,
) -> CommandResult {
  let raw = execute_shell_command(
    command.command,
    workspace,
    command.timeout_ms,
  )
  if raw.timed_out {
    command_timeout(
      command.phase,
      detail="timed out after \{command.timeout_ms} ms: \{command.command}",
    )
  } else {
    {
      phase: command.phase,
      exit_code: if raw.has_exit_code {
        Some(raw.exit_code)
      } else {
        None
      },
      stdout: raw.stdout,
      stderr: raw.stderr,
      timed_out: false,
    }
  }
}

///|
fn skip_selected_results_for_baseline(
  plan : ExecutionPlan,
  mode : SelectionMode,
  baseline : BaselineReport,
) -> Array[ProjectMutantResult] {
  let skipped : Array[ProjectMutantResult] = []
  for execution in select_executions(plan, mode) {
    skipped.push(
      project_result(
        execution.mutation,
        Skipped,
        detail="baseline \{baseline_outcome_label(baseline.outcome)}: \{baseline.detail}",
      ),
    )
  }
  skipped
}

///|
fn workspace_file(workspace : String, relative : String) -> String {
  node_path_join(workspace, relative)
}
