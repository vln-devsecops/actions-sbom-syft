#!/usr/bin/env bats
# Unit tests for scripts/generate-sunshine-report.sh. python3 is stubbed
# (via a PATH-prepended stub dir) so these run fully offline.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/generate-sunshine-report.sh"
  WORKDIR="$(mktemp -d)"
  STUB_DIR="$WORKDIR/stubs"
  BIN_DIR="$WORKDIR/bin"
  mkdir -p "$STUB_DIR" "$BIN_DIR"
  touch "$BIN_DIR/sunshine.py"

  cat >"$STUB_DIR/python3" <<'EOF'
#!/usr/bin/env bash
if [ -n "${STUB_SUNSHINE_FAIL:-}" ]; then
  echo "stub sunshine.py: simulated failure" >&2
  exit 1
fi
out=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    out="$arg"
  fi
  prev="$arg"
done
[ -n "$out" ] && echo "<html>fake report</html>" >"$out"
EOF
  chmod +x "$STUB_DIR/python3"
  export PATH="$STUB_DIR:$PATH"

  cd "$WORKDIR"
  echo '{"metadata":{}}' >sbom.json
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "generate-sunshine-report: fails with a clear error when arguments are missing" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "generate-sunshine-report: fails with a clear error when the SBOM file does not exist" {
  run "$SCRIPT" "$BIN_DIR" "no-such-sbom.json" "report.html"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
  [ ! -f report.html ]
}

@test "generate-sunshine-report: happy path writes the HTML report" {
  run "$SCRIPT" "$BIN_DIR" "sbom.json" "report.html"
  [ "$status" -eq 0 ]
  [ -f report.html ]
  [[ "$(cat report.html)" == *"fake report"* ]]
}

@test "generate-sunshine-report: propagates a sunshine.py failure instead of continuing" {
  export STUB_SUNSHINE_FAIL=1
  run "$SCRIPT" "$BIN_DIR" "sbom.json" "report.html"
  [ "$status" -ne 0 ]
  [ ! -f report.html ]
}
