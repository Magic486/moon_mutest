///|
test "creates and applies text edit for candidate" {
  let source = "let ok = a == b"
  let candidate = @moon_mutest.discover(source, file="a.mbt")[0]
  let edit = @moon_mutest.edit_for_candidate(candidate)
  inspect(edit.file, content="a.mbt")
  inspect(edit.original, content="==")
  inspect(edit.replacement, content="!=")
  inspect(@moon_mutest.validate_edit(source, edit), content="true")
  debug_inspect(
    @moon_mutest.apply_edit(source, edit),
    content="Some(\"let ok = a != b\")",
  )
}

///|
test "rejects stale text edits" {
  let source = "let ok = a == b"
  let candidate = @moon_mutest.discover(source)[0]
  let edit = @moon_mutest.edit_for_candidate(candidate)
  inspect(@moon_mutest.validate_edit("let ok = a != b", edit), content="false")
  assert_true(@moon_mutest.apply_edit("let ok = a != b", edit) is None)
}

///|
test "inverts text edit" {
  let edit : @moon_mutest.TextEdit = {
    file: "a.mbt",
    start: 2,
    end: 4,
    original: "==",
    replacement: "!=",
    line: 1,
    column: 3,
  }
  let inverse = @moon_mutest.invert_edit(edit)
  inspect(inverse.start, content="2")
  inspect(inverse.end, content="4")
  inspect(inverse.original, content="!=")
  inspect(inverse.replacement, content="==")
}

///|
test "previews candidate patch as unified diff" {
  let source = "let ok = a == b\nlet next = true"
  let candidate = @moon_mutest.discover(source, file="a.mbt")[0]
  match @moon_mutest.preview_candidate_patch(source, candidate) {
    Some(preview) =>
      inspect(
        preview.diff,
        content=(
          #|--- a/a.mbt
          #|+++ b/a.mbt
          #|@@ -1,1 +1,1 @@
          #|-let ok = a == b
          #|+let ok = a != b
        ),
      )
    None => fail("expected patch preview")
  }
}
