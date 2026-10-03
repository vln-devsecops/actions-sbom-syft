#!/usr/bin/env bats
# Unit tests for scripts/update-floating-tags.sh using a local bare repo as
# "origin" so pushes are real but fully offline.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/update-floating-tags.sh"
  WORKDIR="$(mktemp -d)"
  REMOTE_DIR="$WORKDIR/origin.git"
  CLONE_DIR="$WORKDIR/clone"

  git init -q --bare "$REMOTE_DIR"
  git clone -q "$REMOTE_DIR" "$CLONE_DIR"
  cd "$CLONE_DIR"
  git config user.email t@example.com
  git config user.name tester
}

teardown() {
  rm -rf "$WORKDIR"
}

commit_and_tag() {
  local tag="$1"
  git commit -q --allow-empty -m "release $tag"
  git tag "$tag"
  git push -q origin HEAD:refs/heads/main "refs/tags/$tag"
}

@test "update-floating-tags: moves vX and vX.Y to the given full version tag" {
  commit_and_tag "v1.2.3"
  sha=$(git rev-parse v1.2.3)

  run "$SCRIPT" "v1.2.3"
  [ "$status" -eq 0 ]

  [ "$(git rev-parse v1)" = "$sha" ]
  [ "$(git rev-parse v1.2)" = "$sha" ]
  [ "$(git ls-remote origin refs/tags/v1 | cut -f1)" = "$sha" ]
  [ "$(git ls-remote origin refs/tags/v1.2 | cut -f1)" = "$sha" ]
}

@test "update-floating-tags: re-pointing to a new patch release moves both floating tags" {
  commit_and_tag "v1.2.3"
  commit_and_tag "v1.2.4"
  sha=$(git rev-parse v1.2.4)

  "$SCRIPT" "v1.2.3" >/dev/null
  run "$SCRIPT" "v1.2.4"
  [ "$status" -eq 0 ]

  [ "$(git rev-parse v1)" = "$sha" ]
  [ "$(git rev-parse v1.2)" = "$sha" ]
  [ "$(git ls-remote origin refs/tags/v1 | cut -f1)" = "$sha" ]
}

@test "update-floating-tags: a new minor release creates its own vX.Y tag and moves vX, leaves the old vX.Y alone" {
  commit_and_tag "v1.2.3"
  old_minor_sha=$(git rev-parse v1.2.3)
  "$SCRIPT" "v1.2.3" >/dev/null

  commit_and_tag "v1.3.0"
  new_sha=$(git rev-parse v1.3.0)
  run "$SCRIPT" "v1.3.0"
  [ "$status" -eq 0 ]

  [ "$(git rev-parse v1)" = "$new_sha" ]
  [ "$(git rev-parse v1.3)" = "$new_sha" ]
  [ "$(git rev-parse v1.2)" = "$old_minor_sha" ]
}

@test "update-floating-tags: fails with a clear error on a malformed tag" {
  commit_and_tag "v1.2.3"
  run "$SCRIPT" "1.2.3"
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected a full version tag"* ]]
}

@test "update-floating-tags: fails on a well-formed but incomplete version (missing patch component)" {
  git commit -q --allow-empty -m "release v1.2"
  git tag "v1.2"
  run "$SCRIPT" "v1.2"
  [ "$status" -ne 0 ]
  [[ "$output" == *"expected a full version tag"* ]]
}

@test "update-floating-tags: correctly splits multi-digit version components" {
  commit_and_tag "v10.20.30"
  sha=$(git rev-parse v10.20.30)

  run "$SCRIPT" "v10.20.30"
  [ "$status" -eq 0 ]

  [ "$(git rev-parse v10)" = "$sha" ]
  [ "$(git rev-parse v10.20)" = "$sha" ]
}

@test "update-floating-tags: fails with a clear error when no argument is given" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "update-floating-tags: fails when the given tag does not exist locally" {
  commit_and_tag "v1.2.3"
  run "$SCRIPT" "v9.9.9"
  [ "$status" -ne 0 ]
  [[ "$output" == *"v9.9.9"* ]]
}
