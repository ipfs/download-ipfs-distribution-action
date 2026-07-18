#!/usr/bin/env bash

CURL_BIN="${CURL_BIN:-curl}"
auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

echo "Downloading $ARCHIVE from the GitHub release asset API"
if ! "$CURL_BIN" --fail --silent --show-error --location --retry 5 \
  --connect-timeout 30 --max-time 600 \
  -H "Accept: application/octet-stream" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${auth[@]}" --output "$ARCHIVE" "$ASSET_API_URL"; then
  echo "::error::Could not download $ARCHIVE from the GitHub release asset API"
  exit 1
fi
