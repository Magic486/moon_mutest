///|
test "default config maps to all-candidate filter" {
  let config = @moon_mutest.MutestConfig::default()
  let filter = config.to_filter()
  inspect(config.commands.length(), content="2")
  inspect(config.fail_fast, content="true")
  inspect(filter.kinds.length(), content="0")
  inspect(filter.labels.length(), content="0")
}

///|
test "parses config from json" {
  let text =
    #|{
    #|  "include_kinds": ["EqualityOperator", "LogicalOperator"],
    #|  "include_labels": ["eq-to-ne"],
    #|  "line_start": 2,
    #|  "line_end": 9,
    #|  "commands": [
    #|    {
    #|      "phase": "CheckPhase",
    #|      "command": "moon check",
    #|      "timeout_ms": 1000
    #|    }
    #|  ],
    #|  "fail_fast": false,
    #|  "max_mutants": 20,
    #|  "report_format": "MarkdownReport"
    #|}
  let config = @moon_mutest.parse_config_json(text)
  inspect(config.include_kinds.length(), content="2")
  inspect(config.include_labels[0], content="eq-to-ne")
  inspect(config.commands[0].command, content="moon check")
  inspect(config.fail_fast, content="false")
  debug_inspect(config.max_mutants, content="Some(20)")
  debug_inspect(config.report_format, content="MarkdownReport")
}

///|
test "formats config for humans" {
  let config : @moon_mutest.MutestConfig = {
    include_kinds: [ArithmeticOperator],
    include_labels: ["add-to-sub"],
    line_start: Some(4),
    line_end: Some(8),
    commands: [{ phase: TestPhase, command: "moon test", timeout_ms: 1234 }],
    fail_fast: false,
    max_mutants: Some(3),
    report_format: MarkdownReport,
  }
  inspect(
    @moon_mutest.format_config(config),
    content=(
      #|Mutation config
      #|fail-fast: false
      #|max-mutants: 3
      #|report-format: markdown
      #|include-kinds: arithmetic
      #|include-labels: add-to-sub
      #|line-range: 4..8
      #|commands:
      #|- test: moon test (1234 ms)
    ),
  )
}
