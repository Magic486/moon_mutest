///|
pub(all) struct Mutant {
  candidate : MutationCandidate
  source : String
} derive(Debug, Eq, ToJson)

///|
pub fn generate_mutants(
  source : String,
  file? : String = "<memory>",
) -> Array[Mutant] {
  [
    for candidate in discover(source, file~) => {
      { candidate, source: apply_mutation(source, candidate) }
    }
  ]
}

///|
pub fn mutant_by_id(
  source : String,
  id : Int,
  file? : String = "<memory>",
) -> Mutant? {
  for mutant in generate_mutants(source, file~) {
    if mutant.candidate.id == id {
      break Some(mutant)
    }
  } nobreak {
    None
  }
}

///|
pub fn format_mutant_patch(mutant : Mutant) -> String {
  let candidate = mutant.candidate
  [
    "mutant #\{candidate.id}: \{candidate.rule.label}",
    "\{candidate.span.file}:\{candidate.span.line}:\{candidate.span.column}",
    "- \{candidate.line_text}",
    "+ \{line_at(mutant.source, candidate.span.start)}",
  ].join("\n")
}
