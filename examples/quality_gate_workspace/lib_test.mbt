///|
test "answer predicate accepts only the expected value" {
  assert_true(is_answer(42))
  assert_false(is_answer(41))
}
