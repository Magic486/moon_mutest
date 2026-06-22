# Repository Layout

MoonBit package boundaries are directory based, so the project now uses real
subpackages for the main functional areas and keeps the module root as a small
facade package.

Top-level layout:

- `exports.mbt`: root facade that re-exports the public API from subpackages so
  users can keep importing `yelfs/moon_mutest`.
- `core/`: source scanning, mutation rules, candidate filtering, and mutant
  generation.
- `io/`: text and JSON manifest construction/serialization.
- `plan/`: project-level mutation plans and workspace source selection.
- `run/`: text edits, execution plans, sharding/selection, batching, command
  classification, baseline gating, scripts, reports, and quality gates.
- `runner/`: JS/Node-backed workspace loading, temporary project copying,
  mutation application, command execution, and live run summaries.
- `tests/`: black-box tests that exercise the public root facade.
- `cmd/main/`: CLI entry point package.
- `docs/`: proposal and project notes.

Package ownership rule:

- Concrete public types live in a non-internal package that owns their methods
  and constructors.
- The root package re-exports those types and functions for user ergonomics.
- Avoid adding new `.mbt` files directly at the module root unless they are
  facade/re-export glue.

Testing rule:

- Put package-private scanner tests beside `core/` as `_wbtest.mbt`.
- Put JS workspace runner integration tests beside `runner/` as `_wbtest.mbt`.
- Put public behavior tests under `tests/` unless a subpackage needs specific
  white-box coverage.
