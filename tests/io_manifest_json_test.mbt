///|
test "builds serializable manifest" {
  let manifest = @moon_mutest.manifest("a == b && false", file="sample.mbt")
  inspect(manifest.summary.candidate_count, content="3")
  inspect(manifest.candidates.length(), content="3")
  inspect(manifest.candidates[2].replacement, content="true")
}

///|
test "formats manifest as json" {
  let text = @moon_mutest.format_manifest_json("a + b", file="math.mbt")
  assert_true(text.contains("\"summary\""))
  assert_true(text.contains("\"candidate_count\": 1"))
  assert_true(text.contains("\"label\": \"add-to-sub\""))
}

///|
test "formats profile manifest as json" {
  let text = @moon_mutest.format_manifest_json_with_profile(
    "let n = 1",
    BoundaryProfile,
    file="n.mbt",
  )
  assert_true(text.contains("\"numeric_count\": 1"))
  assert_true(text.contains("\"label\": \"one-to-zero\""))
}
