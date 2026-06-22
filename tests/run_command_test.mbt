///|
test "classifies test command failures as killed mutants" {
  let candidate = @moon_mutest.discover("a == b")[0]
  let outcome = @moon_mutest.classify_command_result(
    candidate,
    @moon_mutest.command_failure(TestPhase, 1, stderr="assertion failed"),
  )
  debug_inspect(outcome.outcome, content="Killed")
  inspect(outcome.detail, content="assertion failed")
}

///|
test "classifies check failures separately from killed mutants" {
  let candidate = @moon_mutest.discover("a + b")[0]
  let outcome = @moon_mutest.classify_command_result(
    candidate,
    @moon_mutest.command_failure(CheckPhase, 1, stderr="type error"),
  )
  debug_inspect(outcome.outcome, content="CompileError")
  inspect(outcome.detail, content="type error")
}

///|
test "classifies successful command sequence as survived" {
  let candidate = @moon_mutest.discover("a && b")[0]
  let outcome = @moon_mutest.classify_sequence(candidate, [
    @moon_mutest.command_success(CheckPhase),
    @moon_mutest.command_success(TestPhase),
  ])
  debug_inspect(outcome.outcome, content="Survived")
}

///|
test "classifies timeout before later commands" {
  let candidate = @moon_mutest.discover("false")[0]
  let outcome = @moon_mutest.classify_sequence(candidate, [
    @moon_mutest.command_timeout(CheckPhase, detail="30s"),
    @moon_mutest.command_success(TestPhase),
  ])
  debug_inspect(outcome.outcome, content="Timeout")
  inspect(outcome.detail, content="30s")
}
