///|
fn main {
  try root_command().parse(argv=cli_args()) catch {
    err => {
      println("moon-mutest: " + err.to_string())
      set_process_exit_code(2)
    }
  } noraise {
    matches =>
      dispatch(matches) catch {
        err => {
          println("moon-mutest: " + err.to_string())
          set_process_exit_code(2)
        }
      }
  }
}

///|
extern "js" fn set_process_exit_code(code : Int) -> Unit =
  #| code => {
  #|   if (typeof process !== "undefined") {
  #|     process.exitCode = code;
  #|   }
  #| }

///|
struct CliRunConfig {
  profile : String?
  format : String?
  max_mutants : Int?
  first : Int?
  id_start : Int?
  id_end : Int?
  changed_since : String?
  equivalent : Array[CliEquivalentMutant]?
  temp_dir : String?
  include_tests : Bool?
  include_generated : Bool?
  keep_temp : Bool?
  fail_fast : Bool?
  fail_under : Int?
  max_survived : Int?
  max_compile_error : Int?
  max_timeout : Int?
  max_skipped : Int?
  strict_gate : Bool?
  check_command : String?
  test_command : String?
} derive(FromJson)

///|
struct CliEquivalentMutant {
  id : Int
  reason : String
} derive(FromJson)

///|
fn CliRunConfig::empty() -> CliRunConfig {
  {
    profile: None,
    format: None,
    max_mutants: None,
    first: None,
    id_start: None,
    id_end: None,
    changed_since: None,
    equivalent: None,
    temp_dir: None,
    include_tests: None,
    include_generated: None,
    keep_temp: None,
    fail_fast: None,
    fail_under: None,
    max_survived: None,
    max_compile_error: None,
    max_timeout: None,
    max_skipped: None,
    strict_gate: None,
    check_command: None,
    test_command: None,
  }
}

///|
fn cli_args() -> Array[String] {
  let raw = @env.args()
  let args : Array[String] = []
  for index, arg in raw {
    if index > 1 {
      args.push(arg)
    }
  }
  args
}

///|
fn dispatch(matches : @argparse.Matches) -> Unit raise {
  match matches.subcommand {
    Some(("run", sub)) => run_workspace_matches(sub)
    Some(("scan", sub)) => run_scan_matches(sub)
    _ => println(root_command().render_help())
  }
}

///|
fn root_command() -> @argparse.Command {
  Command(
    "moon-mutest",
    about="Mutation testing toolkit for MoonBit projects.",
    version="0.1.7",
    subcommands=[scan_command(), run_command()],
    arg_required_else_help=true,
    subcommand_required=true,
  )
}

///|
fn scan_command() -> @argparse.Command {
  Command(
    "scan",
    about="Discover mutation testing candidates in a MoonBit source snippet.",
    version="0.1.7",
    flags=[FlagArg("json", long="json", about="emit a JSON mutation manifest")],
    options=[
      OptionArg(
        "profile",
        long="profile",
        about="rule profile: basic, boundary, or experimental",
        default_values=["basic"],
      ),
    ],
    positionals=[
      PositionArg(
        "source",
        about="MoonBit source snippet to scan",
        num_args=@argparse.ValueRange::single(),
        allow_hyphen_values=true,
      ),
    ],
  )
}

///|
fn run_command() -> @argparse.Command {
  Command(
    "run",
    about="Execute mutation testing against a real MoonBit workspace.",
    version="0.1.7",
    flags=[
      FlagArg(
        "include-tests",
        long="include-tests",
        about="include *_test.mbt and *_wbtest.mbt files as mutation targets",
      ),
      FlagArg(
        "include-generated",
        long="include-generated",
        about="include generated MoonBit files as mutation targets",
      ),
      FlagArg(
        "keep-temp",
        long="keep-temp",
        about="keep the copied temporary workspace after the run",
      ),
      FlagArg(
        "no-fail-fast",
        long="no-fail-fast",
        about="run all configured commands for each mutant",
      ),
      FlagArg(
        "strict-gate",
        long="strict-gate",
        about="enable strict quality gate defaults",
      ),
    ],
    options=[
      OptionArg(
        "profile",
        long="profile",
        about="rule profile: basic, boundary, or experimental",
      ),
      OptionArg(
        "format",
        long="format",
        about="report format: text, markdown, json, or html",
      ),
      OptionArg(
        "config",
        long="config",
        about="path to moon_mutest JSON config",
      ),
      OptionArg(
        "max-mutants",
        long="max-mutants",
        about="cap planned mutants before execution",
      ),
      OptionArg(
        "first",
        long="first",
        about="execute only the first N planned mutants",
      ),
      OptionArg("id-start", long="id-start", about="start of mutation id range"),
      OptionArg(
        "id-end",
        long="id-end",
        about="end of mutation id range, exclusive",
      ),
      OptionArg(
        "changed-since",
        long="changed-since",
        about="only mutate files changed since this Git reference",
      ),
      OptionArg("temp-dir", long="temp-dir", about="temporary workspace path"),
      OptionArg(
        "fail-under",
        long="fail-under",
        about="minimum mutation score percentage required for exit code 0",
      ),
      OptionArg(
        "max-survived",
        long="max-survived",
        about="maximum survived mutants allowed by the quality gate",
      ),
      OptionArg(
        "max-compile-error",
        long="max-compile-error",
        about="maximum compile-error mutants allowed by the quality gate",
      ),
      OptionArg(
        "max-timeout",
        long="max-timeout",
        about="maximum timeout mutants allowed by the quality gate",
      ),
      OptionArg(
        "max-skipped",
        long="max-skipped",
        about="maximum skipped mutants allowed by the quality gate",
      ),
      OptionArg(
        "check-command",
        long="check-command",
        about="baseline/check command",
      ),
      OptionArg("test-command", long="test-command", about="test command"),
    ],
    positionals=[
      PositionArg(
        "workspace",
        about="MoonBit workspace root",
        default_values=["."],
        num_args=@argparse.ValueRange::single(),
        allow_hyphen_values=true,
      ),
    ],
  )
}

///|
fn run_scan_matches(matches : @argparse.Matches) -> Unit {
  let json = flag(matches, "json")
  let profile_text = value_or(matches, "profile", "basic")
  match matches.values {
    { "source": [source], .. } =>
      match @mutest.parse_rule_profile(profile_text) {
        Some(profile) =>
          if json {
            println(@mutest.format_manifest_json_with_profile(source, profile))
          } else {
            println(@mutest.format_manifest_with_profile(source, profile))
          }
        None => println("moon-mutest: unknown profile " + profile_text)
      }
    _ => println("moon-mutest: expected exactly one source snippet")
  }
}

///|
fn run_workspace_matches(matches : @argparse.Matches) -> Unit raise {
  let workspace = value_or(matches, "workspace", ".")
  let run_config = load_run_config(matches, workspace)
  let profile_text = string_setting(
    matches,
    "profile",
    run_config.profile,
    "basic",
  )
  let profile = match @mutest.parse_rule_profile(profile_text) {
    Some(profile) => profile
    None => {
      println("moon-mutest: unknown profile " + profile_text)
      set_process_exit_code(2)
      return
    }
  }
  let format = string_setting(matches, "format", run_config.format, "text")
  let fail_fast = if flag(matches, "no-fail-fast") {
    false
  } else {
    bool_setting(matches, "fail-fast", run_config.fail_fast, true)
  }
  let config = {
    ..@mutest.MutestConfig::default(),
    max_mutants: int_setting(matches, "max-mutants", run_config.max_mutants),
    fail_fast,
    commands: [
      {
        phase: CheckPhase,
        command: string_setting(
          matches,
          "check-command",
          run_config.check_command,
          "moon check --warn-list +73",
        ),
        timeout_ms: 30000,
      },
      {
        phase: TestPhase,
        command: string_setting(
          matches,
          "test-command",
          run_config.test_command,
          "moon test --warn-list +73",
        ),
        timeout_ms: 60000,
      },
    ],
  }
  let file_spec = {
    ..(if bool_setting(
        matches,
        "include-tests",
        run_config.include_tests,
        false,
      ) {
      @mutest.WorkspaceFileSpec::with_tests()
    } else {
      @mutest.WorkspaceFileSpec::moonbit_default()
    }),
    include_generated: bool_setting(
      matches,
      "include-generated",
      run_config.include_generated,
      false,
    ),
  }
  let options = {
    ..@runner.WorkspaceRunnerOptions::default(workspace),
    temp_workspace: string_option_setting(
      matches,
      "temp-dir",
      run_config.temp_dir,
    ),
    file_spec,
    profile,
    config,
    selection: selection_mode(matches, run_config),
    changed_since: string_option_setting(
      matches,
      "changed-since",
      run_config.changed_since,
    ),
    equivalent_mutants: equivalent_mutants(run_config),
    keep_temp: bool_setting(matches, "keep-temp", run_config.keep_temp, false),
  }
  let report = @runner.run_workspace_mutations(options)
  let gate_report = quality_gate_report(matches, run_config, report)
  match format {
    "text" => {
      println(@runner.format_workspace_run_report(report))
      print_quality_gate_report(gate_report)
    }
    "markdown" => {
      println(@runner.format_workspace_run_markdown(report))
      print_quality_gate_report(gate_report)
    }
    "json" => println(workspace_report_to_json(report, gate_report))
    "html" => println(@runner.format_workspace_run_html(report))
    other => {
      println("moon-mutest: unknown format " + other)
      set_process_exit_code(2)
      return
    }
  }
  apply_quality_gate_exit_code(gate_report)
}

///|
fn equivalent_mutants(config : CliRunConfig) -> Array[@runner.EquivalentMutant] {
  match config.equivalent {
    Some(items) => [ for item in items => { id: item.id, reason: item.reason } ]
    None => []
  }
}

///|
fn quality_gate_report(
  matches : @argparse.Matches,
  config : CliRunConfig,
  report : @runner.WorkspaceRunReport,
) -> @mutest.QualityGateReport? raise {
  match quality_gate_from_matches(matches, config) {
    Some(gate) =>
      Some(
        @mutest.evaluate_quality_gate_after_baseline(
          report.report,
          gate,
          report.baseline,
        ),
      )
    None => None
  }
}

///|
fn quality_gate_from_matches(
  matches : @argparse.Matches,
  config : CliRunConfig,
) -> @mutest.QualityGate? raise {
  let min_score = int_setting(matches, "fail-under", config.fail_under)
  let max_survived = int_setting(matches, "max-survived", config.max_survived)
  let max_compile_error = int_setting(
    matches,
    "max-compile-error",
    config.max_compile_error,
  )
  let max_timeout = int_setting(matches, "max-timeout", config.max_timeout)
  let max_skipped = int_setting(matches, "max-skipped", config.max_skipped)
  let strict = bool_setting(matches, "strict-gate", config.strict_gate, false)
  let has_gate = strict ||
    min_score != None ||
    max_survived != None ||
    max_compile_error != None ||
    max_timeout != None ||
    max_skipped != None
  if !has_gate {
    None
  } else {
    let base = if strict {
      @mutest.QualityGate::strict(
        min_score_percent=optional_int_or(min_score, 90),
      )
    } else {
      @mutest.QualityGate::default()
    }
    Some({
      min_score_percent: optional_int_or(min_score, base.min_score_percent),
      max_survived: optional_limit_or(max_survived, base.max_survived),
      max_compile_error: optional_limit_or(
        max_compile_error,
        base.max_compile_error,
      ),
      max_timeout: optional_limit_or(max_timeout, base.max_timeout),
      max_skipped: optional_limit_or(max_skipped, base.max_skipped),
    })
  }
}

///|
fn print_quality_gate_report(report : @mutest.QualityGateReport?) -> Unit {
  match report {
    Some(report) => {
      println("")
      println(@mutest.format_quality_gate_report(report))
    }
    None => ()
  }
}

///|
fn workspace_report_to_json(
  report : @runner.WorkspaceRunReport,
  gate_report : @mutest.QualityGateReport?,
) -> String {
  match gate_report {
    Some(gate_report) =>
      "{" +
      "\"workspace_run\":" +
      @runner.workspace_run_report_to_json(report, indent=0) +
      "," +
      "\"quality_gate\":" +
      gate_report.to_json().stringify(indent=0) +
      "}"
    None => @runner.workspace_run_report_to_json(report)
  }
}

///|
fn apply_quality_gate_exit_code(report : @mutest.QualityGateReport?) -> Unit {
  match report {
    Some(report) => if report.status != GatePassed { set_process_exit_code(1) }
    None => ()
  }
}

///|
fn optional_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(value) => value
    None => fallback
  }
}

///|
fn optional_limit_or(value : Int?, fallback : Int?) -> Int? {
  match value {
    Some(value) => Some(value)
    None => fallback
  }
}

///|
fn selection_mode(
  matches : @argparse.Matches,
  config : CliRunConfig,
) -> @mutest.SelectionMode raise {
  match
    (
      int_setting(matches, "first", config.first),
      int_setting(matches, "id-start", config.id_start),
      int_setting(matches, "id-end", config.id_end),
    ) {
    (Some(limit), _, _) => FirstMutants(limit)
    (None, Some(start), Some(end)) => IdRange(start~, end~)
    _ => AllMutants
  }
}

///|
fn load_run_config(
  matches : @argparse.Matches,
  workspace : String,
) -> CliRunConfig raise {
  let path = match optional_value(matches, "config") {
    Some(path) => Some(path)
    None => {
      let candidate = join_path(workspace, "moon_mutest.json")
      if @fs.path_exists(candidate) {
        Some(candidate)
      } else {
        None
      }
    }
  }
  match path {
    Some(path) => @json.from_json(@json.parse(@fs.read_file_to_string(path)))
    None => CliRunConfig::empty()
  }
}

///|
fn join_path(base : String, leaf : String) -> String {
  if base == "" || base == "." {
    leaf
  } else if base.has_suffix("/") || base.has_suffix("\\") {
    base + leaf
  } else {
    base + "/" + leaf
  }
}

///|
fn optional_int(matches : @argparse.Matches, name : String) -> Int? raise {
  match optional_value(matches, name) {
    Some(value) => Some(@string.parse_int(value))
    None => None
  }
}

///|
fn int_setting(
  matches : @argparse.Matches,
  name : String,
  config_value : Int?,
) -> Int? raise {
  match optional_int(matches, name) {
    Some(value) => Some(value)
    None => config_value
  }
}

///|
fn string_option_setting(
  matches : @argparse.Matches,
  name : String,
  config_value : String?,
) -> String? {
  match optional_value(matches, name) {
    Some(value) => Some(value)
    None => config_value
  }
}

///|
fn string_setting(
  matches : @argparse.Matches,
  name : String,
  config_value : String?,
  fallback : String,
) -> String {
  match string_option_setting(matches, name, config_value) {
    Some(value) => value
    None => fallback
  }
}

///|
fn bool_setting(
  matches : @argparse.Matches,
  name : String,
  config_value : Bool?,
  fallback : Bool,
) -> Bool {
  if flag(matches, name) {
    true
  } else {
    match config_value {
      Some(value) => value
      None => fallback
    }
  }
}

///|
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some([value]) => Some(value)
    _ => None
  }
}

///|
fn value_or(
  matches : @argparse.Matches,
  name : String,
  fallback : String,
) -> String {
  match optional_value(matches, name) {
    Some(value) => value
    None => fallback
  }
}

///|
fn flag(matches : @argparse.Matches, name : String) -> Bool {
  matches.flags.get_or_default(name, false)
}
