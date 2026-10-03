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
   - No workflow in this repo should use `pull_request_target` with a
     checkout of the PR head; flag it if one ever is added — that
     combination runs untrusted code with privileged secrets.
   - No secrets, tokens, or credentials hard-coded or logged.

2. **SCA (software composition / supply chain)**
   - All third-party GitHub Actions (`uses:`) must be pinned to a specific
     version tag (e.g. `@v4.1.2`), not a floating major tag (`@v4`, `@v3`)
     and not `@main`/`@latest`. Verify the tag is a real, resolvable release
     of that action (e.g. via the GitHub UI or `git ls-remote --tags`), not
     a typo or a tag that doesn't exist.
   - Any pinned tool version (Syft, cosign, bats-core, etc.) must likewise
     be a real, resolvable release; flag anything pinned to `latest`/`main`/
     a floating major tag.
   - New dependencies (vendored scripts, submodules, npm/pip packages) must
     be justified — flag unnecessary or unmaintained dependencies.

3. **Test coverage — BDD**
   - This area applies whenever a PR adds or changes anything under
     `features/` or any script/workflow behavior a `features/*.feature`
     scenario describes — not only when the `.feature` file itself is
     touched. Treat "we added behavior but didn't update/add a scenario"
     as a finding, not an N/A.
   - Every Gherkin scenario in `features/*.feature` must have a
     corresponding executable acceptance test under `tests/bdd/` (or
     `tests/e2e/`) that exercises the same Given/When/Then.
   - Flag scenarios that exist only as prose with no executable counterpart.

4. **Test coverage — TDD**
   - This area applies whenever a PR adds or changes a function in
     `scripts/*.sh` — not only when `tests/unit/*.bats` itself is touched.
     A new script or function with no corresponding unit test is always a
     finding, never N/A.
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
branches after a fix lands. A PR should not be opened for review until the
PR it stacks on has itself reached APPROVE — reviewing out of order means
reviewing a diff whose base may still change.
