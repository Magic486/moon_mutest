///|
pub(all) struct ShellCommandOutput {
  has_exit_code : Bool
  exit_code : Int
  stdout : String
  stderr : String
  timed_out : Bool
} derive(Debug, Eq, ToJson)

///|
#external
priv type JsExecOptions

///|
#external
priv type JsShellCommandOutput

///|
#module("node:child_process")
extern "js" fn exec_sync(command : String, options : JsExecOptions) -> String = "execSync"

///|
extern "js" fn run_shell_command_ffi(
  exec : (String, JsExecOptions) -> String,
  command : String,
  cwd : String,
  timeout_ms : Int,
) -> JsShellCommandOutput =
  #| function(exec, command, cwd, timeoutMs) {
  #|   try {
  #|     const stdout = exec(command, {
  #|       cwd,
  #|       timeout: timeoutMs,
  #|       encoding: "utf8",
  #|       windowsHide: true,
  #|       stdio: ["ignore", "pipe", "pipe"]
  #|     });
  #|     return {
  #|       hasExitCode: true,
  #|       exitCode: 0,
  #|       stdout: stdout == null ? "" : String(stdout),
  #|       stderr: "",
  #|       timedOut: false
  #|     };
  #|   } catch (error) {
  #|     const status = typeof error.status === "number" ? error.status : 1;
  #|     const stdout = error.stdout == null ? "" : String(error.stdout);
  #|     const stderrValue = error.stderr == null ? "" : String(error.stderr);
  #|     const message = error.message == null ? "" : String(error.message);
  #|     const timedOut = error.code === "ETIMEDOUT" || error.signal === "SIGTERM";
  #|     return {
  #|       hasExitCode: typeof error.status === "number",
  #|       exitCode: status,
  #|       stdout,
  #|       stderr: stderrValue === "" ? message : stderrValue,
  #|       timedOut
  #|     };
  #|   }
  #| }

///|
extern "js" fn JsShellCommandOutput::has_exit_code(self : Self) -> Bool =
  #| output => output.hasExitCode

///|
extern "js" fn JsShellCommandOutput::exit_code(self : Self) -> Int =
  #| output => output.exitCode

///|
extern "js" fn JsShellCommandOutput::stdout(self : Self) -> String =
  #| output => output.stdout

///|
extern "js" fn JsShellCommandOutput::stderr(self : Self) -> String =
  #| output => output.stderr

///|
extern "js" fn JsShellCommandOutput::timed_out(self : Self) -> Bool =
  #| output => output.timedOut

///|
pub fn execute_shell_command(
  command : String,
  cwd : String,
  timeout_ms : Int,
) -> ShellCommandOutput {
  let output = run_shell_command_ffi(exec_sync, command, cwd, timeout_ms)
  {
    has_exit_code: output.has_exit_code(),
    exit_code: output.exit_code(),
    stdout: output.stdout(),
    stderr: output.stderr(),
    timed_out: output.timed_out(),
  }
}
