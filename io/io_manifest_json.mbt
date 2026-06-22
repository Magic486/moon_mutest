///|
pub(all) struct MutationManifest {
  summary : MutationSummary
  candidates : Array[MutationCandidate]
} derive(Debug, Eq, ToJson)

///|
pub fn manifest(
  source : String,
  file? : String = "<memory>",
) -> MutationManifest {
  let candidates = discover(source, file~)
  { summary: summarize_candidates(file, candidates), candidates }
}

///|
pub fn manifest_with_profile(
  source : String,
  profile : RuleProfile,
  file? : String = "<memory>",
) -> MutationManifest {
  let candidates = discover_with_profile(source, profile, file~)
  { summary: summarize_candidates(file, candidates), candidates }
}

///|
pub fn candidate_to_json_string(
  candidate : MutationCandidate,
  indent? : Int = 2,
) -> String {
  candidate.to_json().stringify(indent~)
}

///|
pub fn manifest_to_json_string(
  manifest : MutationManifest,
  indent? : Int = 2,
) -> String {
  manifest.to_json().stringify(indent~)
}

///|
pub fn format_manifest_json(
  source : String,
  file? : String = "<memory>",
) -> String {
  manifest_to_json_string(manifest(source, file~))
}

///|
pub fn format_manifest_json_with_profile(
  source : String,
  profile : RuleProfile,
  file? : String = "<memory>",
) -> String {
  manifest_to_json_string(manifest_with_profile(source, profile, file~))
}
