///|
pub(all) enum RuleProfile {
  BasicProfile
  BoundaryProfile
  ExperimentalProfile
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct RuleCatalogEntry {
  rule : MutationRule
  profile : RuleProfile
  description : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RuleSetValidation {
  rule_count : Int
  duplicate_labels : Array[String]
  empty_tokens : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn profile_label(profile : RuleProfile) -> String {
  match profile {
    BasicProfile => "basic"
    BoundaryProfile => "boundary"
    ExperimentalProfile => "experimental"
  }
}

///|
pub fn mutation_kind_label(kind : MutationKind) -> String {
  match kind {
    BooleanLiteral => "boolean"
    EqualityOperator => "equality"
    RelationalOperator => "relational"
    ArithmeticOperator => "arithmetic"
    LogicalOperator => "logical"
    NumericLiteral => "numeric"
  }
}

///|
pub fn parse_rule_profile(text : String) -> RuleProfile? {
  match text {
    "basic" | "BasicProfile" => Some(BasicProfile)
    "boundary" | "BoundaryProfile" => Some(BoundaryProfile)
    "experimental" | "ExperimentalProfile" => Some(ExperimentalProfile)
    _ => None
  }
}

///|
pub fn rule(
  kind : MutationKind,
  from : String,
  to : String,
  label : String,
) -> MutationRule {
  { kind, from, to, label }
}

///|
pub fn rule_catalog() -> Array[RuleCatalogEntry] {
  let entries : Array[RuleCatalogEntry] = []
  for rule in default_rules() {
    entries.push({
      rule,
      profile: BasicProfile,
      description: basic_rule_description(rule.label),
    })
  }
  for rule in boundary_literal_rules() {
    entries.push({
      rule,
      profile: BoundaryProfile,
      description: boundary_rule_description(rule.label),
    })
  }
  for rule in experimental_rules() {
    entries.push({
      rule,
      profile: ExperimentalProfile,
      description: experimental_rule_description(rule.label),
    })
  }
  entries
}

///|
pub fn rules_for_profile(profile : RuleProfile) -> Array[MutationRule] {
  match profile {
    BasicProfile => default_rules()
    BoundaryProfile => boundary_literal_rules() + default_rules()
    ExperimentalProfile =>
      experimental_rules() + boundary_literal_rules() + default_rules()
  }
}

///|
pub fn boundary_literal_rules() -> Array[MutationRule] {
  [
    rule(NumericLiteral, "0", "1", "zero-to-one"),
    rule(NumericLiteral, "1", "0", "one-to-zero"),
    rule(NumericLiteral, "-1", "0", "minus-one-to-zero"),
  ]
}

///|
/// Strong operator replacements intended for a small, opt-in experimental run.
pub fn experimental_rules() -> Array[MutationRule] {
  [
    rule(RelationalOperator, "<=", ">", "le-to-gt"),
    rule(RelationalOperator, "<", ">=", "lt-to-ge"),
    rule(RelationalOperator, ">=", "<", "ge-to-lt"),
    rule(RelationalOperator, ">", "<=", "gt-to-le"),
    rule(ArithmeticOperator, "+", "*", "add-to-mul"),
    rule(ArithmeticOperator, "-", "*", "sub-to-mul"),
    rule(ArithmeticOperator, "*", "+", "mul-to-add"),
    rule(ArithmeticOperator, "/", "+", "div-to-add"),
  ]
}

///|
pub fn discover_with_profile(
  source : String,
  profile : RuleProfile,
  file? : String = "<memory>",
) -> Array[MutationCandidate] {
  discover_with_rules(source, rules_for_profile(profile), file~)
}

///|
pub fn validate_rules(rules : ArrayView[MutationRule]) -> RuleSetValidation {
  let duplicate_labels : Array[String] = []
  let empty_tokens : Array[String] = []
  for index, rule in rules {
    if rule.from == "" || rule.to == "" {
      empty_tokens.push(rule.label)
    }
    for other_index in (index + 1)..<rules.length() {
      let other = rules[other_index]
      if rule.label == other.label && !duplicate_labels.contains(rule.label) {
        duplicate_labels.push(rule.label)
      }
    }
  }
  { rule_count: rules.length(), duplicate_labels, empty_tokens }
}

///|
pub fn format_rule_catalog(profile? : RuleProfile) -> String {
  let selected = match profile {
    Some(value) => rule_catalog().filter(entry => entry.profile == value)
    None => rule_catalog()
  }
  let lines : Array[String] = [
    "Mutation rule catalog", "| Profile | Kind | Label | Change |", "| --- | --- | --- | --- |",
  ]
  for entry in selected {
    let rule = entry.rule
    lines.push(
      "| \{profile_label(entry.profile)} | \{mutation_kind_label(rule.kind)} | " +
      "\{rule.label} | `\{rule.from}` -> `\{rule.to}` |",
    )
  }
  lines.join("\n")
}

///|
fn basic_rule_description(label : String) -> String {
  match label {
    "eq-to-ne" => "turns equality checks into inequality checks"
    "ne-to-eq" => "turns inequality checks into equality checks"
    "and-to-or" => "weakens a conjunction into a disjunction"
    "or-to-and" => "strengthens a disjunction into a conjunction"
    "true-to-false" => "flips a true literal"
    "false-to-true" => "flips a false literal"
    _ => "operator replacement"
  }
}

///|
fn boundary_rule_description(label : String) -> String {
  match label {
    "zero-to-one" => "moves a zero boundary up by one"
    "one-to-zero" => "moves a one boundary down to zero"
    "minus-one-to-zero" => "moves a negative sentinel to zero"
    _ => "numeric boundary replacement"
  }
}

///|
fn experimental_rule_description(label : String) -> String {
  match label {
    "le-to-gt" | "lt-to-ge" | "ge-to-lt" | "gt-to-le" =>
      "inverts a relational boundary"
    "add-to-mul" | "sub-to-mul" | "mul-to-add" | "div-to-add" =>
      "replaces arithmetic with a stronger alternative"
    _ => "experimental operator replacement"
  }
}
