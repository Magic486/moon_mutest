///|
pub(all) struct WorkspaceSnapshot {
  root : String
  files : Array[SourceFile]
  selected_files : Array[SourceFile]
  selection : WorkspaceSelectionReport
} derive(Debug, Eq, ToJson)

///|
pub fn load_workspace_snapshot(
  root : String,
  spec : WorkspaceFileSpec,
) -> WorkspaceSnapshot raise {
  let normalized_root = normalize_native_path(root)
  let files = collect_moonbit_sources(normalized_root)
  let selection = summarize_workspace_selection(files, spec)
  {
    root: normalized_root,
    files,
    selected_files: select_workspace_files(files, spec),
    selection,
  }
}

///|
pub fn copy_workspace_for_mutation(
  source_root : String,
  temp_root : String,
) -> Unit raise {
  let source_root = normalize_native_path(source_root)
  let temp_root = normalize_native_path(temp_root)
  guard temp_root != "" && temp_root != source_root else {
    raise @fs.IOError("unsafe temporary workspace path: " + temp_root)
  }
  if @fs.path_exists(temp_root) {
    remove_tree(temp_root)
  }
  ensure_dir(temp_root)
  copy_tree(source_root, temp_root, temp_root)
}

///|
pub fn remove_workspace_tree(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_tree(path)
  }
}

///|
pub fn default_temp_workspace(root : String) -> String {
  join_path(join_path(root, "_build"), "moon-mutest-workspace-\{@env.now()}")
}

///|
fn collect_moonbit_sources(root : String) -> Array[SourceFile] raise {
  let files : Array[SourceFile] = []
  collect_moonbit_sources_into(root, "", files)
  files.sort_by((left, right) => left.path.compare(right.path))
  files
}

///|
fn collect_moonbit_sources_into(
  dir : String,
  relative_dir : String,
  files : Array[SourceFile],
) -> Unit raise {
  let entries = @fs.read_dir(dir)
  entries.sort()
  for entry in entries {
    let relative = join_relative(relative_dir, entry)
    let full = join_path(dir, entry)
    if should_skip_workspace_segment(entry) {
      ()
    } else if @fs.is_dir(full) {
      collect_moonbit_sources_into(full, relative, files)
    } else if @fs.is_file(full) && relative.has_suffix(".mbt") {
      files.push(source_file(relative, @fs.read_file_to_string(full)))
    }
  }
}

///|
fn copy_tree(source : String, dest : String, temp_root : String) -> Unit raise {
  let entries = @fs.read_dir(source)
  entries.sort()
  for entry in entries {
    let source_child = join_path(source, entry)
    let dest_child = join_path(dest, entry)
    if should_skip_workspace_segment(entry) ||
      same_native_path(source_child, temp_root) {
      ()
    } else if @fs.is_dir(source_child) {
      ensure_dir(dest_child)
      copy_tree(source_child, dest_child, temp_root)
    } else if @fs.is_file(source_child) {
      ensure_dir(dirname(dest_child))
      @fs.write_bytes_to_file(dest_child, @fs.read_file_to_bytes(source_child))
    }
  }
}

///|
fn remove_tree(path : String) -> Unit raise {
  if @fs.is_dir(path) {
    let entries = @fs.read_dir(path)
    entries.sort()
    for entry in entries {
      remove_tree(join_path(path, entry))
    }
    @fs.remove_dir(path)
  } else if @fs.is_file(path) {
    @fs.remove_file(path)
  }
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if path == "" || @fs.path_exists(path) {
    ()
  } else {
    let parent = dirname(path)
    if parent != "" && parent != path && !@fs.path_exists(parent) {
      ensure_dir(parent)
    }
    if !@fs.path_exists(path) {
      @fs.create_dir(path)
    }
  }
}

///|
fn dirname(path : String) -> String {
  node_path_dirname(path)
}

///|
fn join_path(left : String, right : String) -> String {
  node_path_join(left, right)
}

///|
fn join_relative(left : String, right : String) -> String {
  if left == "" {
    normalize_workspace_path(right)
  } else {
    normalize_workspace_path(left + "/" + right)
  }
}

///|
fn normalize_native_path(path : String) -> String {
  node_path_resolve(path)
}

///|
fn normalize_workspace_path(path : String) -> String {
  path.replace(old="\\", new="/")
}

///|
fn same_native_path(left : String, right : String) -> Bool {
  node_path_normalize(left) == node_path_normalize(right)
}

///|
fn should_skip_workspace_segment(segment : String) -> Bool {
  segment == "_build" ||
  segment == ".git" ||
  segment == ".moon" ||
  segment == ".mooncakes" ||
  segment == ".repos" ||
  segment == "node_modules"
}
