///|
pub(all) enum MutationKind {
  BooleanLiteral
  EqualityOperator
  RelationalOperator
  ArithmeticOperator
  LogicalOperator
  NumericLiteral
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct MutationRule {
  kind : MutationKind
  from : String
  to : String
  label : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SourceSpan {
  file : String
  start : Int
  end : Int
  line : Int
  column : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MutationCandidate {
  id : Int
  rule : MutationRule
  span : SourceSpan
  original : String
  replacement : String
  line_text : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MutationSummary {
  file : String
  candidate_count : Int
  boolean_count : Int
  equality_count : Int
  relational_count : Int
  arithmetic_count : Int
  logical_count : Int
  numeric_count : Int
} derive(Debug, Eq, ToJson)

///|
pub fn default_rules() -> Array[MutationRule] {
  [
    { kind: EqualityOperator, from: "==", to: "!=", label: "eq-to-ne" },
    { kind: EqualityOperator, from: "!=", to: "==", label: "ne-to-eq" },
    { kind: RelationalOperator, from: "<=", to: "<", label: "le-to-lt" },
    { kind: RelationalOperator, from: "<", to: "<=", label: "lt-to-le" },
    { kind: RelationalOperator, from: ">=", to: ">", label: "ge-to-gt" },
    { kind: RelationalOperator, from: ">", to: ">=", label: "gt-to-ge" },
    { kind: ArithmeticOperator, from: "+", to: "-", label: "add-to-sub" },
    { kind: ArithmeticOperator, from: "-", to: "+", label: "sub-to-add" },
    { kind: ArithmeticOperator, from: "*", to: "/", label: "mul-to-div" },
    { kind: ArithmeticOperator, from: "/", to: "*", label: "div-to-mul" },
    { kind: LogicalOperator, from: "&&", to: "||", label: "and-to-or" },
    { kind: LogicalOperator, from: "||", to: "&&", label: "or-to-and" },
    { kind: BooleanLiteral, from: "true", to: "false", label: "true-to-false" },
    { kind: BooleanLiteral, from: "false", to: "true", label: "false-to-true" },
  ]
}

///|
pub fn discover(
  source : String,
  file? : String = "<memory>",
) -> Array[MutationCandidate] {
  discover_with_rules(source, default_rules(), file~)
}

///|
pub fn discover_with_rules(
  source : String,
  rules : ArrayView[MutationRule],
  file? : String = "<memory>",
) -> Array[MutationCandidate] {
  let found : Array[MutationCandidate] = []
  for i = 0, line = 1, column = 1; i < source.length(); {
    if starts_with_at(source, i, "//") {
      let (next_i, next_line, next_column) = skip_line_comment(
        source, i, line, column,
      )
      continue next_i, next_line, next_column
    } else if starts_with_at(source, i, "/*") {
      let (next_i, next_line, next_column) = skip_block_comment(
        source, i, line, column,
      )
      continue next_i, next_line, next_column
    } else if source[i] == '"' {
      let (next_i, next_line, next_column) = skip_string(
        source, i, line, column,
      )
      continue next_i, next_line, next_column
    } else if source[i] == '\'' {
      let (next_i, next_line, next_column) = skip_char(source, i, line, column)
      continue next_i, next_line, next_column
    } else {
      let matched_rules = rules_at(source, i, rules)
      if !line_at(source, i).contains("mutest:ignore") {
        for rule in matched_rules {
          let end = i + rule.from.length()
          found.push({
            id: found.length(),
            rule,
            span: { file, start: i, end, line, column },
            original: rule.from,
            replacement: rule.to,
            line_text: line_at(source, i),
          })
        }
      }
      let (next_i, next_line, next_column) = advance(source, i, line, column)
      continue next_i, next_line, next_column
    }
  }
  found
}

///|
pub fn apply_mutation(source : String, candidate : MutationCandidate) -> String {
  source[0:candidate.span.start].to_owned() +
  candidate.replacement +
  source[candidate.span.end:source.length()].to_owned()
}

///|
pub fn summarize(
  source : String,
  file? : String = "<memory>",
) -> MutationSummary {
  let candidates = discover(source, file~)
  summarize_candidates(file, candidates)
}

///|
pub fn summarize_candidates(
  file : String,
  candidates : ArrayView[MutationCandidate],
) -> MutationSummary {
  let mut boolean_count = 0
  let mut equality_count = 0
  let mut relational_count = 0
  let mut arithmetic_count = 0
  let mut logical_count = 0
  let mut numeric_count = 0
  for candidate in candidates {
    match candidate.rule.kind {
      BooleanLiteral => boolean_count += 1
      EqualityOperator => equality_count += 1
      RelationalOperator => relational_count += 1
      ArithmeticOperator => arithmetic_count += 1
      LogicalOperator => logical_count += 1
      NumericLiteral => numeric_count += 1
    }
  }
  {
    file,
    candidate_count: candidates.length(),
    boolean_count,
    equality_count,
    relational_count,
    arithmetic_count,
    logical_count,
    numeric_count,
  }
}

///|
fn rules_at(
  source : String,
  index : Int,
  rules : ArrayView[MutationRule],
) -> Array[MutationRule] {
  let matched : Array[MutationRule] = []
  let mut longest_token = 0
  for rule in rules {
    if starts_with_at(source, index, rule.from) &&
      token_boundary(source, index, rule.from) &&
      rule.from.length() > longest_token {
      longest_token = rule.from.length()
    }
  }
  for rule in rules {
    if starts_with_at(source, index, rule.from) &&
      token_boundary(source, index, rule.from) &&
      rule.from.length() == longest_token {
      matched.push(rule)
    }
  }
  matched
}

///|
fn token_boundary(source : String, index : Int, token : String) -> Bool {
  if is_keyword_token(token) {
    let before = if index == 0 { None } else { source.get_char(index - 1) }
    let after = source.get_char(index + token.length())
    !is_ident_char(before) && !is_ident_char(after)
  } else if is_numeric_token(token) {
    let before = if index == 0 { None } else { source.get_char(index - 1) }
    let after = source.get_char(index + token.length())
    !is_numeric_boundary_char(before) && !is_numeric_boundary_char(after)
  } else {
    structural_token_allowed(source, index, token)
  }
}

///|
fn is_numeric_token(token : String) -> Bool {
  for ch in token {
    match ch {
      '-' | '0'..='9' => ()
      _ => return false
    }
  }
  token.contains("0") ||
  token.contains("1") ||
  token.contains("2") ||
  token.contains("3") ||
  token.contains("4") ||
  token.contains("5") ||
  token.contains("6") ||
  token.contains("7") ||
  token.contains("8") ||
  token.contains("9")
}

///|
fn is_numeric_boundary_char(ch : Char?) -> Bool {
  match ch {
    Some('a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '.' | '-') => true
    _ => false
  }
}

///|
fn structural_token_allowed(
  source : String,
  index : Int,
  token : String,
) -> Bool {
  match token {
    "-" => !starts_with_at(source, index, "->")
    ">" => index == 0 || (source[index - 1] != '-' && source[index - 1] != '=')
    "<" => index == 0 || source[index - 1] != '.'
    _ => true
  }
}

///|
fn is_keyword_token(token : String) -> Bool {
  token == "true" || token == "false"
}

///|
fn is_ident_char(ch : Char?) -> Bool {
  match ch {
    Some('a'..='z' | 'A'..='Z' | '0'..='9' | '_') => true
    _ => false
  }
}

///|
fn starts_with_at(source : String, index : Int, needle : String) -> Bool {
  index + needle.length() <= source.length() &&
  source[index:index + needle.length()].to_owned() == needle
}

///|
fn advance(
  source : String,
  index : Int,
  line : Int,
  column : Int,
) -> (Int, Int, Int) {
  if source[index] == '\n' {
    (index + 1, line + 1, 1)
  } else {
    (index + 1, line, column + 1)
  }
}

///|
fn skip_line_comment(
  source : String,
  index : Int,
  line : Int,
  column : Int,
) -> (Int, Int, Int) {
  for i = index, c = column; i < source.length(); {
    if source[i] == '\n' {
      break (i + 1, line + 1, 1)
    } else {
      continue i + 1, c + 1
    }
  } nobreak {
    (source.length(), line, c)
  }
}

///|
fn skip_block_comment(
  source : String,
  index : Int,
  line : Int,
  column : Int,
) -> (Int, Int, Int) {
  for i = index + 2, l = line, c = column + 2; i < source.length(); {
    if starts_with_at(source, i, "*/") {
      break (i + 2, l, c + 2)
    } else if source[i] == '\n' {
      continue i + 1, l + 1, 1
    } else {
      continue i + 1, l, c + 1
    }
  } nobreak {
    (source.length(), l, c)
  }
}

///|
fn skip_string(
  source : String,
  index : Int,
  line : Int,
  column : Int,
) -> (Int, Int, Int) {
  for i = index + 1, l = line, c = column + 1, escaped = false; i <
     source.length(); {
    if escaped {
      let (next_i, next_line, next_column) = advance(source, i, l, c)
      continue next_i, next_line, next_column, false
    } else if source[i] == '\\' {
      continue i + 1, l, c + 1, true
    } else if source[i] == '"' {
      break (i + 1, l, c + 1)
    } else if source[i] == '\n' {
      continue i + 1, l + 1, 1, false
    } else {
      continue i + 1, l, c + 1, false
    }
  } nobreak {
    (source.length(), l, c)
  }
}

///|
fn skip_char(
  source : String,
  index : Int,
  line : Int,
  column : Int,
) -> (Int, Int, Int) {
  for i = index + 1, c = column + 1, escaped = false; i < source.length(); {
    if escaped {
      continue i + 1, c + 1, false
    } else if source[i] == '\\' {
      continue i + 1, c + 1, true
    } else if source[i] == '\'' {
      break (i + 1, line, c + 1)
    } else {
      continue i + 1, c + 1, false
    }
  } nobreak {
    (source.length(), line, c)
  }
}

///|
fn line_at(source : String, index : Int) -> String {
  let start = for i = index; i > 0; {
    if source[i - 1] == '\n' {
      break i
    } else {
      continue i - 1
    }
  } nobreak {
    0
  }
  let end = for i = index; i < source.length(); {
    if source[i] == '\n' {
      break i
    } else {
      continue i + 1
    }
  } nobreak {
    source.length()
  }
  source[start:end].to_owned()
}
