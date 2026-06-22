///|
pub(all) enum CommandPhase {
  CheckPhase
  TestPhase
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CommandResult {
  phase : CommandPhase
  exit_code : Int?
  stdout : String
  stderr : String
  timed_out : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn command_success(phase : CommandPhase) -> CommandResult {
  { phase, exit_code: Some(0), stdout: "", stderr: "", timed_out: false }
}

///|
pub fn command_failure(
  phase : CommandPhase,
  code : Int,
  stdout? : String = "",
  stderr? : String = "",
) -> CommandResult {
  { phase, exit_code: Some(code), stdout, stderr, timed_out: false }
}

///|
pub fn command_timeout(
  phase : CommandPhase,
  detail? : String = "",
) -> CommandResult {
  { phase, exit_code: None, stdout: "", stderr: detail, timed_out: true }
}

///|
pub fn classify_command_result(
  candidate : MutationCandidate,
  command : CommandResult,
) -> MutantResult {
  if command.timed_out {
    result(candidate, Timeout, detail=command.stderr)
  } else {
    match command.exit_code {
      Some(0) => result(candidate, Survived)
      Some(_) =>
        match command.phase {
          CheckPhase => result(candidate, CompileError, detail=command.stderr)
          TestPhase => result(candidate, Killed, detail=command.stderr)
        }
      None =>
        result(
          candidate,
          Skipped,
          detail="command did not produce an exit code",
        )
    }
  }
}

///|
pub fn classify_sequence(
  candidate : MutationCandidate,
  commands : ArrayView[CommandResult],
) -> MutantResult {
  for command in commands {
    let outcome = classify_command_result(candidate, command)
    if outcome.outcome != Survived {
      break outcome
    }
  } nobreak {
    result(candidate, Survived)
  }
}
