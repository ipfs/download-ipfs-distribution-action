#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

run_resolver() {
  local scenario="$1"
  local version="$2"
  local name="${3:-kubo}"
  : > "$TMP/output"
  AUTH_LOG="$TMP/auth" \
  CALL_LOG="$TMP/calls" \
  FIXTURE_ROOT="$ROOT/tests/fixtures" \
  FIXTURE_SCENARIO="$scenario" \
  CURL_BIN="$ROOT/tests/fake-curl.sh" \
  GITHUB_OUTPUT="$TMP/output" \
  GITHUB_ACTION_PATH="$ROOT" \
  GITHUB_API_URL="https://api.github.test" \
  GITHUB_TOKEN="fixture-token" \
  NAME="$name" VERSION="$version" GITHUB_REPO="example/private-releases" \
  INSTALL_DIRECTORY="" OS="linux" ARCH="amd64" PREFIX="fixture" \
  bash -e -o pipefail "$ROOT/scripts/resolve-release.sh"
}

run_resolver latest-fallback ""
grep -q '^archive=kubo_v1.2.3_linux-amd64.tar.gz$' "$TMP/output"
grep -q '^asset-api-url=https://api.github.com/repos/example/private-releases/releases/assets/123$' "$TMP/output"
grep -q '^cache-key=fixture-example/private-releases-kubo-v1.2.3-linux-amd64-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa$' "$TMP/output"
grep -q '^authorization-present$' "$TMP/auth"

run_resolver latest ""
grep -q '^archive=kubo_v1.2.3_linux-amd64.tar.gz$' "$TMP/output"

run_resolver pagination ""
grep -q '/releases?per_page=100&page=2$' "$TMP/calls"

run_resolver pinned v1.2.3
grep -q '^archive=kubo_v1.2.3_linux-amd64.tar.gz$' "$TMP/output"

if run_resolver pinned v1.2.2 > "$TMP/missing-digest.log" 2>&1; then
  echo "expected a missing digest to fail" >&2
  exit 1
fi
grep -q 'has no published SHA-256 digest' "$TMP/missing-digest.log"

if run_resolver pinned v1.2.4 > "$TMP/missing-asset.log" 2>&1; then
  echo "expected a missing asset to fail" >&2
  exit 1
fi
grep -q 'does not contain' "$TMP/missing-asset.log"

if run_resolver api-error v1.2.3 > "$TMP/api-error.log" 2>&1; then
  echo "expected an API error to fail closed" >&2
  exit 1
fi
grep -q 'status: 401' "$TMP/api-error.log"

if run_resolver pinned v1.2.3 '../unsafe' > "$TMP/invalid-name.log" 2>&1; then
  echo "expected an unsafe name to fail" >&2
  exit 1
fi
grep -q 'name must start with an alphanumeric' "$TMP/invalid-name.log"

run_unmapped() {
  GITHUB_OUTPUT="$TMP/output" \
  GITHUB_ACTION_PATH="$ROOT" \
  CURL_BIN="$ROOT/tests/fake-curl.sh" \
  NAME="not-in-the-map" VERSION="" GITHUB_REPO="" \
  INSTALL_DIRECTORY="" OS="linux" ARCH="amd64" PREFIX="fixture" \
  env "$@" bash -e -o pipefail "$ROOT/scripts/resolve-release.sh"
}

if run_unmapped GITHUB_ACTION_REPOSITORY="ipfs/download-ipfs-distribution-action" GITHUB_ACTION_REF="v2.0.0" \
  > "$TMP/unmapped-remote.log" 2>&1; then
  echo "expected an unmapped name to fail" >&2
  exit 1
fi
grep -q 'blob/v2.0.0/distributions.json' "$TMP/unmapped-remote.log"

if run_unmapped > "$TMP/unmapped-local.log" 2>&1; then
  echo "expected an unmapped name to fail" >&2
  exit 1
fi
grep -q "the action's distributions.json" "$TMP/unmapped-local.log"

python3 "$ROOT/tests/redirect-server.py" "$TMP/redirect.log" "$TMP/port" &
server_pid=$!
for _ in $(seq 1 50); do
  [ -s "$TMP/port" ] && break
  sleep 0.1
done
port="$(cat "$TMP/port")"
(
  cd "$TMP"
  ARCHIVE="downloaded-asset" \
  ASSET_API_URL="http://127.0.0.1:$port/asset" \
  GITHUB_TOKEN="private-token" \
  bash -e -o pipefail "$ROOT/scripts/download-asset.sh"
)
wait "$server_pid"
grep -q 'fixture archive' "$TMP/downloaded-asset"
jq -e 'select(.path == "/asset" and .authorization == "Bearer private-token")' "$TMP/redirect.log" >/dev/null
jq -e 'select(.path == "/cdn" and .authorization == null)' "$TMP/redirect.log" >/dev/null

echo "script tests passed"
