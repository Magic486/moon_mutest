///|
pub(all) struct SourceFile {
  path : String
  content : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProjectMutation {
  global_id : Int
  file_index : Int
  file : String
  local_id : Int
  candidate : MutationCandidate
  mutated_source : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct FileMutationPlan {
  file : String
  file_index : Int
  start_id : Int
  end_id : Int
  summary : MutationSummary
  candidates : Array[MutationCandidate]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProjectMutationPlan {
  file_count : Int
  mutation_count : Int
  files : Array[FileMutationPlan]
  mutations : Array[ProjectMutation]
} derive(Debug, Eq, ToJson)

///|
pub fn source_file(path : String, content : String) -> SourceFile {
  { path, content }
}

///|
pub fn plan_project(files : ArrayView[SourceFile]) -> ProjectMutationPlan {
  plan_project_filtered(files, MutationFilter::all())
}

///|
pub fn plan_project_filtered(
  files : ArrayView[SourceFile],
  filter : MutationFilter,
) -> ProjectMutationPlan {
  let file_plans : Array[FileMutationPlan] = []
  let mutations : Array[ProjectMutation] = []
  let mut next_id = 0
  for file_index, source in files {
    let candidates = discover_filtered(source.content, filter, file=source.path)
    let start_id = next_id
    for candidate in candidates {
      mutations.push({
        global_id: next_id,
        file_index,
        file: source.path,
        local_id: candidate.id,
        candidate,
        mutated_source: apply_mutation(source.content, candidate),
      })
      next_id += 1
    }
    file_plans.push({
      file: source.path,
      file_index,
      start_id,
      end_id: next_id,
      summary: summarize_candidates(source.path, candidates),
      candidates,
    })
  }
  {
    file_count: files.length(),
    mutation_count: mutations.length(),
    files: file_plans,
    mutations,
  }
}

///|
pub fn project_mutation_by_id(
  plan : ProjectMutationPlan,
  global_id : Int,
) -> ProjectMutation? {
  for mutation in plan.mutations {
    if mutation.global_id == global_id {
      break Some(mutation)
    }
  } nobreak {
    None
  }
}

///|
pub fn format_project_mutation(mutation : ProjectMutation) -> String {
  "#\{mutation.global_id} " +
  "\{mutation.file}:\{mutation.candidate.span.line}:\{mutation.candidate.span.column} " +
  "\{mutation.candidate.rule.label} " +
  "\{mutation.candidate.original} -> \{mutation.candidate.replacement}"
}

///|
pub fn format_project_plan_summary(plan : ProjectMutationPlan) -> String {
  let lines : Array[String] = [
    "Project mutation plan",
    "files: \{plan.file_count}",
    "mutations: \{plan.mutation_count}",
  ]
  for file in plan.files {
    lines.push(
      "- \{file.file}: \{file.summary.candidate_count} candidates " +
      "(ids \{file.start_id}..\{file.end_id})",
    )
  }
  lines.join("\n")
}

///|
pub fn format_project_plan(plan : ProjectMutationPlan) -> String {
  let lines : Array[String] = [format_project_plan_summary(plan), ""]
  if plan.mutations.is_empty() {
    lines.push("No project mutation candidates found.")
  } else {
    for mutation in plan.mutations {
      lines.push(format_project_mutation(mutation))
    }
  }
  lines.join("\n")
}
