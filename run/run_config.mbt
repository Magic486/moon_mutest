///|
pub(all) enum ReportFormat {
  TextReport
  MarkdownReport
  JsonReport
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RunnerCommand {
  phase : CommandPhase
  command : String
  timeout_ms : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct MutestConfig {
  include_kinds : Array[MutationKind]
  include_labels : Array[String]
  line_start : Int?
  line_end : Int?
  commands : Array[RunnerCommand]
  fail_fast : Bool
  max_mutants : Int?
  report_format : ReportFormat
} derive(Debug, Eq, ToJson, FromJson)

///|
pub fn default_commands() -> Array[RunnerCommand] {
  [
    {
      phase: CheckPhase,
      command: "moon check --warn-list +73",
      timeout_ms: 30000,
    },
    {
      phase: TestPhase,
      command: "moon test --warn-list +73",
      timeout_ms: 60000,
    },
  ]
}

///|
pub fn MutestConfig::default() -> MutestConfig {
  {
    include_kinds: [],
    include_labels: [],
    line_start: None,
    line_end: None,
    commands: default_commands(),
    fail_fast: true,
    max_mutants: None,
    report_format: TextReport,
  }
}

///|
pub fn MutestConfig::to_filter(self : MutestConfig) -> MutationFilter {
  {
    kinds: self.include_kinds,
    labels: self.include_labels,
    line_start: self.line_start,
    line_end: self.line_end,
  }
}

///|
pub fn parse_config_json(text : String) -> MutestConfig raise {
  @json.from_json(@json.parse(text))
}

///|
pub fn config_to_json_string(
  config : MutestConfig,
  indent? : Int = 2,
) -> String {
  config.to_json().stringify(indent~)
}

///|
pub fn command_phase_label(phase : CommandPhase) -> String {
  match phase {
    CheckPhase => "check"
    TestPhase => "test"
  }
}

///|
pub fn format_runner_command(command : RunnerCommand) -> String {
  "\{command_phase_label(command.phase)}: \{command.command} (\{command.timeout_ms} ms)"
}

///|
pub fn format_config(config : MutestConfig) -> String {
  let lines : Array[String] = [
    "Mutation config",
    "fail-fast: \{config.fail_fast}",
    "max-mutants: \{format_optional_int(config.max_mutants)}",
    "report-format: \{report_format_label(config.report_format)}",
    "include-kinds: \{format_kind_list(config.include_kinds)}",
    "include-labels: \{format_string_list(config.include_labels)}",
    "line-range: \{format_line_range(config.line_start, config.line_end)}",
    "commands:",
  ]
  for command in config.commands {
    lines.push("- " + format_runner_command(command))
  }
  lines.join("\n")
}

///|
pub fn report_format_label(format : ReportFormat) -> String {
  match format {
    TextReport => "text"
    MarkdownReport => "markdown"
    JsonReport => "json"
  }
}

///|
fn format_optional_int(value : Int?) -> String {
  match value {
    Some(n) => n.to_string()
    None => "unlimited"
  }
}

///|
fn format_line_range(start : Int?, end : Int?) -> String {
  match (start, end) {
    (Some(a), Some(b)) => "\{a}..\{b}"
    (Some(a), None) => "\{a}.."
    (None, Some(b)) => "..\{b}"
    (None, None) => "all"
  }
}

///|
fn format_kind_list(kinds : ArrayView[MutationKind]) -> String {
  if kinds.is_empty() {
    "all"
  } else {
    [ for kind in kinds => mutation_kind_label(kind) ].join(", ")
  }
}

///|
fn format_string_list(items : ArrayView[String]) -> String {
  if items.is_empty() {
    "all"
  } else {
    items.join(", ")
  }
}
