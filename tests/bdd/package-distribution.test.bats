#!/usr/bin/env bats
# Acceptance tests for features/package-distribution.feature,
# the two scenarios implemented by scripts/attach-package.sh so far:
# Maven JAR embedding and npm tarball embedding. The attestation and
# GHCR/release distribution scenarios in that feature are implemented
# by action.yml wiring added later in the stack.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/attach-package.sh"
  WORKDIR="$(mktemp -d)"
  cd "$WORKDIR"
  echo '{"metadata":{"component":{"name":"placeholder"}}}' >sbom.json
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "Scenario: Opt-In Language Archive Embedding (Maven JAR)" {
  # Given a compiled Java archive at "build/libs/service-1.0.0.jar"
  mkdir -p build/libs com/example
  echo "class bytes" >com/example/App.class
  (cd . && zip -q -r build/libs/service-1.0.0.jar com)

  # When the action runs with package-type=maven, package-file-path=that jar
  run "$SCRIPT" "maven" "build/libs/service-1.0.0.jar" "sbom.json"
  [ "$status" -eq 0 ]

  # Then the file "META-INF/sbom/application-sbom.json" exists inside the jar
  extract_dir="$(mktemp -d)"
  unzip -q build/libs/service-1.0.0.jar -d "$extract_dir"
  [ -f "$extract_dir/META-INF/sbom/application-sbom.json" ]
  rm -rf "$extract_dir"
}

@test "Scenario: Opt-In Language Archive Embedding (npm Tarball)" {
  # Given a packaged npm archive at "dist/my-package-1.0.0.tgz"
  mkdir -p dist package
  echo '{"name":"my-package","version":"1.0.0"}' >package/package.json
  tar -czf dist/my-package-1.0.0.tgz package

  # When the action runs with package-type=npm, package-file-path=that tarball
  run "$SCRIPT" "npm" "dist/my-package-1.0.0.tgz" "sbom.json"
  [ "$status" -eq 0 ]

  # Then the file "package/sbom.json" should exist inside the tarball
  extract_dir="$(mktemp -d)"
  tar -xzf dist/my-package-1.0.0.tgz -C "$extract_dir"
  [ -f "$extract_dir/package/sbom.json" ]
  rm -rf "$extract_dir"
}
