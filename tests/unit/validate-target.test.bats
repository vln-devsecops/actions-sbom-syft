#!/usr/bin/env bats

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/validate-target.sh"
  WORKDIR="$(mktemp -d)"
  cd "$WORKDIR"
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "validate-target: accepts the current directory" {
  run "$SCRIPT" "."
  [ "$status" -eq 0 ]
}

@test "validate-target: accepts an existing relative directory" {
  mkdir -p subdir
  run "$SCRIPT" "subdir"
  [ "$status" -eq 0 ]
}

@test "validate-target: accepts an existing file" {
  touch archive.tar
  run "$SCRIPT" "archive.tar"
  [ "$status" -eq 0 ]
}

@test "validate-target: rejects a non-existent relative path with a clear error" {
  run "$SCRIPT" "path/to/nonexistent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"target path does not exist"* ]]
}

@test "validate-target: rejects a non-existent bare filename" {
  run "$SCRIPT" "does-not-exist.tgz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"target path does not exist"* ]]
}

@test "validate-target: does not validate a container image reference as a filesystem path" {
  run "$SCRIPT" "ghcr.io/my-org/my-app:v1.0.0"
  [ "$status" -eq 0 ]
}

@test "validate-target: does not validate a docker-archive: scheme reference" {
  run "$SCRIPT" "docker-archive:/tmp/whatever-not-a-real-file.tar"
  [ "$status" -eq 0 ]
}

@test "validate-target: does not validate a registry: scheme reference" {
  run "$SCRIPT" "registry:index.docker.io/library/alpine:latest"
  [ "$status" -eq 0 ]
}

@test "validate-target: does not validate a bare image reference with a tag and no slash" {
  run "$SCRIPT" "alpine:latest"
  [ "$status" -eq 0 ]
}

@test "validate-target: does not validate an untagged, registry-qualified image reference" {
  run "$SCRIPT" "ghcr.io/my-org/my-app"
  [ "$status" -eq 0 ]
}

@test "validate-target: does not validate a localhost-registry image reference" {
  run "$SCRIPT" "localhost/my-org/my-app"
  [ "$status" -eq 0 ]
}

@test "validate-target: rejects a non-existent multi-segment local path whose first segment has no dot" {
  run "$SCRIPT" "dist/my-package-1.0.0.tgz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"target path does not exist"* ]]
}
