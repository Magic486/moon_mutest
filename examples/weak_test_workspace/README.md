# moon_mutest weak test fixture

This workspace intentionally contains a weak assertion. It is used to
demonstrate that `moon_mutest` can report a survived mutant when tests execute
but do not check the behavior strongly enough.

Run from the repository root:

```bash
moon run --target js cmd/main -- run examples/weak_test_workspace --max-mutants 1 --first 1 --temp-dir _build/weak-test-example-run
```

Expected signal:

- `killed: 0`
- `survived: 1`
- `score: 0%`
