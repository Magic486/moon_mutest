///|
test "published moon_mutest package can be consumed" {
  let manifest = @moon_mutest.manifest("value == limit && true")
  inspect(manifest.summary.candidate_count, content="3")
}
