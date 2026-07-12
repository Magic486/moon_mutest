///|
extern "js" fn split_changed_file_lines(output : String) -> Array[String] =
  #| output => output
  #|   .split(/\r?\n/)
  #|   .map(path => path.trim().replace(/\\/g, "/"))
  #|   .filter(path => path.length > 0)

///|
extern "js" fn first_nonempty_output_line(output : String) -> String =
  #| output => output.split(/\r?\n/).map(line => line.trim()).find(Boolean) || ""

///|
extern "js" fn is_safe_git_reference(reference : String) -> Bool =
  #| reference => /^[A-Za-z0-9._/:~^-]+$/.test(reference)

///|
/// Return root-relative files added, copied, modified, or renamed since a
/// Git reference. The working tree is included so local edits are covered.
pub fn changed_workspace_files_since(
  workspace : String,
  reference : String,
) -> Array[String] raise {
  guard is_safe_git_reference(reference) else {
    raise @fs.IOError("invalid Git reference for --changed-since: " + reference)
  }
  let merge_base = execute_shell_command(
    "git merge-base " + reference + " HEAD",
    workspace,
    15000,
  )
  if merge_base.timed_out {
    raise @fs.IOError("git merge-base timed out for reference: " + reference)
  } else if !merge_base.has_exit_code || merge_base.exit_code != 0 {
    let detail = if merge_base.stderr != "" {
      merge_base.stderr
    } else {
      merge_base.stdout
    }
    raise @fs.IOError("git merge-base failed for " + reference + ": " + detail)
  } else {
    let base = first_nonempty_output_line(merge_base.stdout)
    guard base != "" else {
      raise @fs.IOError("git merge-base returned no commit for: " + reference)
    }
    let result = execute_shell_command(
      "git diff --relative --name-only --diff-filter=ACMR " + base + " --",
      workspace,
      15000,
    )
    if result.timed_out {
      raise @fs.IOError("git diff timed out for reference: " + reference)
    } else if !result.has_exit_code || result.exit_code != 0 {
      let detail = if result.stderr != "" {
        result.stderr
      } else {
        result.stdout
      }
      raise @fs.IOError("git diff failed for " + reference + ": " + detail)
    } else {
      split_changed_file_lines(result.stdout)
    }
  }
}
