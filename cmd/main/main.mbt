///|
fn main {
  try root_command().parse(argv=cli_args()) catch {
    err => println("moon-mutest: " + err.to_string())
  } noraise {
    matches =>
      dispatch(matches) catch {
        err => println("moon-mutest: " + err.to_string())
      }
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
    version="0.1.0",
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
    version="0.1.0",
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
    version="0.1.0",
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
    ],
    options=[
      OptionArg(
        "profile",
        long="profile",
        about="rule profile: basic, boundary, or experimental",
        default_values=["basic"],
      ),
      OptionArg(
        "format",
        long="format",
        about="report format: text, markdown, or json",
        default_values=["text"],
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
      OptionArg("temp-dir", long="temp-dir", about="temporary workspace path"),
      OptionArg(
        "check-command",
        long="check-command",
        about="baseline/check command",
        default_values=["moon check --warn-list +73"],
      ),
      OptionArg("test-command", long="test-command", about="test command", default_values=[
        "moon test --warn-list +73",
      ]),
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
  let profile_text = value_or(matches, "profile", "basic")
  let profile = match @mutest.parse_rule_profile(profile_text) {
    Some(profile) => profile
    None => {
      println("moon-mutest: unknown profile " + profile_text)
      return
    }
  }
  let format = value_or(matches, "format", "text")
  let workspace = value_or(matches, "workspace", ".")
  let config = {
    ..@mutest.MutestConfig::default(),
    max_mutants: optional_int(matches, "max-mutants"),
    fail_fast: !flag(matches, "no-fail-fast"),
    commands: [
      {
        phase: CheckPhase,
        command: value_or(
          matches, "check-command", "moon check --warn-list +73",
        ),
        timeout_ms: 30000,
      },
      {
        phase: TestPhase,
        command: value_or(matches, "test-command", "moon test --warn-list +73"),
        timeout_ms: 60000,
      },
    ],
  }
  let file_spec = {
    ..(if flag(matches, "include-tests") {
      @mutest.WorkspaceFileSpec::with_tests()
    } else {
      @mutest.WorkspaceFileSpec::moonbit_default()
    }),
    include_generated: flag(matches, "include-generated"),
  }
  let options = {
    ..@runner.WorkspaceRunnerOptions::default(workspace),
    temp_workspace: optional_value(matches, "temp-dir"),
    file_spec,
    profile,
    config,
    selection: selection_mode(matches),
    keep_temp: flag(matches, "keep-temp"),
  }
  let report = @runner.run_workspace_mutations(options)
  match format {
    "text" => println(@runner.format_workspace_run_report(report))
    "markdown" => println(@runner.format_workspace_run_markdown(report))
    "json" => println(@runner.workspace_run_report_to_json(report))
    other => println("moon-mutest: unknown format " + other)
  }
}

///|
fn selection_mode(matches : @argparse.Matches) -> @mutest.SelectionMode raise {
  match
    (
      optional_int(matches, "first"),
      optional_int(matches, "id-start"),
      optional_int(matches, "id-end"),
    ) {
    (Some(limit), _, _) => FirstMutants(limit)
    (None, Some(start), Some(end)) => IdRange(start~, end~)
    _ => AllMutants
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
