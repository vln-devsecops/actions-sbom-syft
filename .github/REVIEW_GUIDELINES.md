# Review Guidelines

This repository is built as a stack of small pull requests, each one layered
on top of the previous one (PR N targets the branch of PR N-1, and the
bottom of the stack targets `dev`). Every PR in the stack MUST be reviewed by
a **fresh** review agent before the next PR in the stack is opened — "fresh"
meaning an agent instance with no memory of earlier review rounds, so it
judges the diff on its own merits instead of rubber-stamping prior approval.

## What the reviewer must check

A review is not complete unless it explicitly addresses all five of the
following areas. If an area does not apply to a given PR (e.g. a docs-only
PR has no SCA surface), say so explicitly rather than omitting it.

1. **SAST (static analysis of the shell/CI code)**
   - Every `.sh` file must pass `shellcheck` with no unsuppressed warnings.
     Any `# shellcheck disable=` must carry a one-line reason.
   - Every `.sh` file must be `shfmt`-formatted (`shfmt -d`).
   - `action.yml` and workflow YAML must not interpolate untrusted input
     (PR titles/bodies, issue text, branch names, etc.) directly into
     `run:` blocks — use `env:` indirection to avoid script injection.
   - No secrets, tokens, or credentials hard-coded or logged.

2. **SCA (software composition / supply chain)**
   - All third-party GitHub Actions (`uses:`) must be pinned to a full
     commit SHA (not a mutable tag like `@v3`), with a trailing comment
     noting the human-readable version, per GitHub's supply-chain hardening
     guidance.
   - Any pinned tool version (Syft, cosign, bats-core, etc.) must be a real,
     resolvable release; flag anything pinned to `latest`/`main`/a floating
     major tag.
   - New dependencies (vendored scripts, submodules, npm/pip packages) must
     be justified — flag unnecessary or unmaintained dependencies.

3. **Test coverage — BDD**
   - Every Gherkin scenario touched or added by the PR in `features/*.feature`
     must have a corresponding executable acceptance test under
     `tests/bdd/` (or `tests/e2e/`) that exercises the same Given/When/Then.
   - Flag scenarios that exist only as prose with no executable counterpart.

4. **Test coverage — TDD**
   - Every new/changed function in `scripts/*.sh` must have unit tests in
     `tests/unit/*.bats` covering at least: the happy path, one documented
     edge case, and one failure/error path.
   - Tests must actually fail if the implementation is reverted (no tests
     that pass trivially regardless of behavior).

5. **Code smells & actual issues**
   - Correctness bugs, unhandled error paths, missing `set -euo pipefail`,
     unquoted variable expansions, race conditions in temp-file handling.
   - Duplication that should be extracted, dead code, overly clever code.
   - Naming, consistency with the rest of the codebase, and whether the
     change matches the scope described in the PR (no unrelated drive-by
     changes).

## Review verdict

Each review must end with one of:
- **APPROVE** — all five areas checked, no blocking findings.
- **CHANGES REQUESTED** — list concrete, file:line-anchored findings; the
  PR must not advance in the stack until these are resolved and re-reviewed
  by another fresh agent.

## Process note for stacked PRs

Because each PR stacks on the last, a finding in an earlier PR must be
fixed in that PR (not papered over downstream). Rebase/update dependent
branches after a fix lands.
