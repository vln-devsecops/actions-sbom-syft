#!/usr/bin/env bats

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/attach-package.sh"
  WORKDIR="$(mktemp -d)"
  cd "$WORKDIR"
  echo '{"metadata":{}}' >sbom.json
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "attach-package: package-type 'none' is a no-op" {
  run "$SCRIPT" "none" "" "sbom.json"
  [ "$status" -eq 0 ]
}

@test "attach-package: fails when package-type is set but no file-path is given" {
  run "$SCRIPT" "npm" "" "sbom.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"package-file-path"* ]]
}

@test "attach-package: fails when the target package file does not exist" {
  run "$SCRIPT" "npm" "missing.tgz" "sbom.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "attach-package: fails when the sbom file does not exist" {
  mkdir -p package
  echo '{"name":"x"}' >package/package.json
  tar -czf my-package.tgz package
  run "$SCRIPT" "npm" "my-package.tgz" "no-such-sbom.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "attach-package: fails on an unsupported package-type" {
  echo "dummy" >archive.bin
  run "$SCRIPT" "rpm" "archive.bin" "sbom.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported package-type"* ]]
}

@test "attach-package: npm embeds sbom.json under package/" {
  mkdir -p package
  echo '{"name":"my-pkg","version":"1.0.0"}' >package/package.json
  tar -czf my-package-1.0.0.tgz package

  run "$SCRIPT" "npm" "my-package-1.0.0.tgz" "sbom.json"
  [ "$status" -eq 0 ]

  extract_dir="$(mktemp -d)"
  tar -xzf my-package-1.0.0.tgz -C "$extract_dir"
  [ -f "$extract_dir/package/sbom.json" ]
  [ -f "$extract_dir/package/package.json" ]
  [ "$(jq -r '.metadata' "$extract_dir/package/sbom.json")" = "{}" ]
  rm -rf "$extract_dir"
}

@test "attach-package: maven embeds application-sbom.json under META-INF/sbom/" {
  mkdir -p com/example
  echo "class bytes" >com/example/App.class
  zip -q -r service.jar com

  run "$SCRIPT" "maven" "service.jar" "sbom.json"
  [ "$status" -eq 0 ]

  extract_dir="$(mktemp -d)"
  unzip -q service.jar -d "$extract_dir"
  [ -f "$extract_dir/META-INF/sbom/application-sbom.json" ]
  [ -f "$extract_dir/com/example/App.class" ]
  rm -rf "$extract_dir"
}

@test "attach-package: nuget embeds sbom.json at the package root" {
  echo '<?xml version="1.0"?><package/>' >my.nuspec
  zip -q my-package.nupkg my.nuspec

  run "$SCRIPT" "nuget" "my-package.nupkg" "sbom.json"
  [ "$status" -eq 0 ]

  extract_dir="$(mktemp -d)"
  unzip -q my-package.nupkg -d "$extract_dir"
  [ -f "$extract_dir/sbom.json" ]
  [ -f "$extract_dir/my.nuspec" ]
  rm -rf "$extract_dir"
}
