#!/usr/bin/env bats

setup() {
  FIXTURE_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures" && pwd)"
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/resolve-version.sh"
  WORKDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "resolve-version: uses explicit version when provided" {
  run "$SCRIPT" "2.0.0" "${FIXTURE_DIR}/.release-please-manifest.json" "."
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "resolve-version: explicit version wins even when manifest and git tag exist" {
  cd "$WORKDIR"
  git init -q
  git config user.email t@example.com
  git config user.name tester
  git commit -q --allow-empty -m init
  git tag v9.9.9
  cp "${FIXTURE_DIR}/.release-please-manifest.json" .

  run "$SCRIPT" "3.0.0" ".release-please-manifest.json" "."
  [ "$status" -eq 0 ]
  [ "$output" = "3.0.0" ]
}

@test "resolve-version: parses root version from release-please manifest" {
  run "$SCRIPT" "" "${FIXTURE_DIR}/.release-please-manifest.json" "."
  [ "$status" -eq 0 ]
  [ "$output" = "1.8.2" ]
}

@test "resolve-version: parses nested package version from release-please manifest" {
  run "$SCRIPT" "" "${FIXTURE_DIR}/.release-please-manifest.json" "packages/service-a"
  [ "$status" -eq 0 ]
  [ "$output" = "0.4.1" ]
}

@test "resolve-version: falls back to manifest root when target path has no entry" {
  run "$SCRIPT" "" "${FIXTURE_DIR}/.release-please-manifest.json" "packages/unknown-service"
  [ "$status" -eq 0 ]
  [ "$output" = "1.8.2" ]
}

@test "resolve-version: falls back to git describe if manifest file is missing" {
  cd "$WORKDIR"
  git init -q
  git config user.email t@example.com
  git config user.name tester
  git commit -q --allow-empty -m init
  git tag v1.4.0

  run "$SCRIPT" "" "non-existent-manifest.json" "."
  [ "$status" -eq 0 ]
  [ "$output" = "1.4.0" ]
}

@test "resolve-version: falls back to a draft placeholder with no manifest and no git tags" {
  cd "$WORKDIR"
  run "$SCRIPT" "" "non-existent-manifest.json" "."
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]
}

@test "resolve-version: treats a malformed manifest as missing and falls back" {
  cd "$WORKDIR"
  git init -q
  git config user.email t@example.com
  git config user.name tester
  git commit -q --allow-empty -m init
  git tag v5.5.5
  echo "{not valid json" > bad-manifest.json

  run "$SCRIPT" "" "bad-manifest.json" "."
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = "5.5.5" ]
}

@test "resolve-version: defaults manifest path and target to current directory conventions" {
  cd "$WORKDIR"
  cp "${FIXTURE_DIR}/.release-please-manifest.json" .
  run "$SCRIPT" ""
  [ "$status" -eq 0 ]
  [ "$output" = "1.8.2" ]
}
