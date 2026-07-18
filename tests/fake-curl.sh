#!/usr/bin/env bash

url=""
previous=""
for argument in "$@"; do
  if [[ "$argument" == http://* || "$argument" == https://* ]]; then
    url="$argument"
  fi
  if [ "$previous" = "Authorization: Bearer fixture-token" ] && [ -n "${AUTH_LOG:-}" ]; then
    printf 'authorization-present\n' >> "$AUTH_LOG"
  fi
  previous="$argument"
done
if [ -n "${CALL_LOG:-}" ]; then
  printf '%s\n' "$url" >> "$CALL_LOG"
fi

if [ "${FIXTURE_SCENARIO:-}" = "api-error" ]; then
  printf '\n401'
  exit 0
fi

case "$url" in
  */releases/latest)
    if [ "${FIXTURE_SCENARIO:-}" = "latest-fallback" ] || [ "${FIXTURE_SCENARIO:-}" = "pagination" ]; then
      fixture="latest-faulty.json"
    else
      fixture="latest-usable.json"
    fi
    ;;
  *'/releases?per_page=100&page=1')
    if [ "${FIXTURE_SCENARIO:-}" = "pagination" ]; then
      jq -nc '[range(0; 100) | {tag_name: ("draft-" + tostring), draft: true, prerelease: false, published_at: "2026-07-18T00:00:00Z", assets: []}]'
      printf '\n200'
      exit 0
    fi
    fixture="releases.json"
    ;;
  *'/releases?per_page=100&page=2') fixture="releases.json" ;;
  */releases/tags/v1.2.3) fixture="latest-usable.json" ;;
  */releases/tags/v1.2.2) fixture="pinned-missing-digest.json" ;;
  */releases/tags/v1.2.4) fixture="pinned-missing-asset.json" ;;
  *) printf '\n404'; exit 0 ;;
esac

cat "$FIXTURE_ROOT/$fixture"
printf '\n200'
