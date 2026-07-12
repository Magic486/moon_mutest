# moon_mutest quality gate fixture

This is a minimal MoonBit workspace used by the repository CI to prove that
`moon_mutest` can execute a real workspace mutation run and kill at least one
mutant.

Run from the repository root:

```bash
moon run --target js cmd/main -- run examples/quality_gate_workspace --max-mutants 1 --first 1 --temp-dir _build/quality-gate-example-run
```

The workspace also includes `moon_mutest.json`, so the same gate can be run
with the checked-in configuration:

```bash
moon run --target js cmd/main -- run examples/quality_gate_workspace --config examples/quality_gate_workspace/moon_mutest.json --temp-dir _build/quality-gate-config-run
```

Expected signal:

- `killed: 1`
- `survived: 0`
- `score: 100%`
- `status: passed`
