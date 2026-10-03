#!/usr/bin/env bats
# Unit tests for scripts/install-sunshine.sh. curl and python3 are stubbed
# (via a PATH-prepended stub dir) so these run fully offline and can
# simulate failures.

setup() {
  SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../scripts" && pwd)/install-sunshine.sh"
  WORKDIR="$(mktemp -d)"
  STUB_DIR="$WORKDIR/stubs"
  BIN_DIR="$WORKDIR/bin"
  mkdir -p "$STUB_DIR" "$BIN_DIR"

  cat >"$STUB_DIR/curl" <<'EOF'
#!/usr/bin/env bash
if [ -n "${STUB_CURL_FAIL:-}" ]; then
  echo "stub curl: simulated failure" >&2
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
[ -n "$out" ] && echo "#!/usr/bin/env python3
# fake sunshine.py" >"$out"
EOF
  chmod +x "$STUB_DIR/curl"

  cat >"$STUB_DIR/python3" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-m" ] && [ "$2" = "pip" ]; then
  if [ -n "${STUB_PIP_FAIL:-}" ]; then
    echo "stub pip: simulated failure" >&2
    exit 1
  fi
  echo "$*" >"$STUB_PIP_INSTALL_LOG"
  exit 0
fi
EOF
  chmod +x "$STUB_DIR/python3"

  export STUB_PIP_INSTALL_LOG="$WORKDIR/pip-install.log"
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  rm -rf "$WORKDIR"
}

@test "install-sunshine: fails with a clear error when no arguments are given" {
  run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "install-sunshine: fails with a clear error when commit sha is missing" {
  run "$SCRIPT" "$BIN_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "install-sunshine: happy path downloads sunshine.py and installs a pinned requests version" {
  run "$SCRIPT" "$BIN_DIR" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  [ "$status" -eq 0 ]
  [ -f "$BIN_DIR/sunshine.py" ]

  # the dependency is pinned to an exact version we control, not whatever
  # the fetched repo's own requirements.txt happens to say
  run cat "$STUB_PIP_INSTALL_LOG"
  [[ "$output" == *"requests==2."* ]]
}

@test "install-sunshine: propagates a curl failure instead of continuing" {
  export STUB_CURL_FAIL=1
  run "$SCRIPT" "$BIN_DIR" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  [ "$status" -ne 0 ]
  [ ! -f "$BIN_DIR/sunshine.py" ]
}

@test "install-sunshine: propagates a pip install failure instead of continuing" {
  export STUB_PIP_FAIL=1
  run "$SCRIPT" "$BIN_DIR" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
  [ "$status" -ne 0 ]
}
