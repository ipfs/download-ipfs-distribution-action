#!/usr/bin/env bash
set -u

error() {
  echo "::error::$*"
}

# Shown whenever the API answers 401, 403 or 404: all three look identical from
# here, and a scoped-down workflow token is the most common cause.
TOKEN_HINT="If the repository is private, or the workflow token is scoped down, pass a token with Contents: read access through the github-token input."

if ! [[ "$NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  error "name must start with an alphanumeric character and contain only letters, numbers, dots, underscores, or hyphens"
  exit 1
fi
if [ -n "$VERSION" ] && ! [[ "$VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
  error "version must start with an alphanumeric character and contain only letters, numbers, dots, underscores, plus signs, or hyphens"
  exit 1
fi
if [ -n "$GITHUB_REPO" ] && ! [[ "$GITHUB_REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  error "github-repo must be an owner/repo on GitHub.com"
  exit 1
fi
if ! [[ "$PREFIX" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  error "prefix must start with an alphanumeric character and contain only letters, numbers, dots, underscores, or hyphens"
  exit 1
fi
case "$INSTALL_DIRECTORY" in
  *$'\n'*|*$'\r'*) error "install-directory must not contain newlines"; exit 1 ;;
esac

if [ "$OS" = "windows" ]; then EXT="zip"; else EXT="tar.gz"; fi
SUFFIX="${OS}-${ARCH}.${EXT}"

REPO="$GITHUB_REPO"
if [ -z "$REPO" ] && [ -f "$GITHUB_ACTION_PATH/distributions.json" ]; then
  REPO="$(jq -r --arg n "$NAME" '.[$n] // empty' "$GITHUB_ACTION_PATH/distributions.json")"
fi
if [ -z "$REPO" ]; then
  # Point at the map belonging to the ref the caller pinned, not at a hardcoded
  # one: a moving tag or the default branch can list a repo this version cannot
  # resolve. Both variables are empty when the action runs from a local path.
  MAP_LOCATION="the action's distributions.json"
  if [ -n "${GITHUB_ACTION_REPOSITORY:-}" ] && [ -n "${GITHUB_ACTION_REF:-}" ]; then
    MAP_LOCATION="https://github.com/$GITHUB_ACTION_REPOSITORY/blob/$GITHUB_ACTION_REF/distributions.json"
  fi
  error "No GitHub repository for '$NAME'. Set the github-repo input, or add a mapping to $MAP_LOCATION"
  exit 1
fi

GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
CURL_BIN="${CURL_BIN:-curl}"
API_BODY=""
API_STATUS=""

api_get() {
  local endpoint="$1"
  local response
  local auth=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  if ! response="$("$CURL_BIN" --silent --show-error --location --retry 5 \
    --connect-timeout 30 --max-time 120 \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    ${auth[@]+"${auth[@]}"} --write-out $'\n%{http_code}' "$GITHUB_API_URL/$endpoint")"; then
    API_STATUS="network"
    API_BODY=""
    return 1
  fi
  API_STATUS="${response##*$'\n'}"
  API_BODY="${response%$'\n'*}"
  [ "$API_STATUS" = "200" ]
}

select_asset() {
  local release_json="$1"
  local wanted_name="$2"
  printf '%s' "$release_json" | jq -r --arg want "$wanted_name" '
    .assets[]?
    | select(.name == $want)
    | [.url, (.digest // "")]
    | @tsv' | head -n1
}

valid_asset_line() {
  local line="$1"
  local digest
  digest="$(printf '%s' "$line" | cut -f2)"
  [[ "$digest" =~ ^sha256:[0-9A-Fa-f]{64}$ ]]
}

resolve_pinned() {
  ARCHIVE="${NAME}_${VERSION}_${SUFFIX}"
  if ! api_get "repos/$REPO/releases/tags/$VERSION"; then
    case "$API_STATUS" in
      404) error "Release '$VERSION' was not found in '$REPO'. $TOKEN_HINT" ;;
      401|403) error "The GitHub API refused the request for release '$VERSION' in '$REPO' (status: $API_STATUS). $TOKEN_HINT" ;;
      *) error "Could not query release '$VERSION' in '$REPO' from the GitHub API (status: $API_STATUS)" ;;
    esac
    exit 1
  fi

  local line
  line="$(select_asset "$API_BODY" "$ARCHIVE")"
  if [ -z "$line" ]; then
    error "Release '$VERSION' in '$REPO' does not contain '$ARCHIVE'"
    exit 1
  fi
  if ! valid_asset_line "$line"; then
    error "Release asset '$ARCHIVE' has no published SHA-256 digest"
    exit 1
  fi
  ASSET_API_URL="$(printf '%s' "$line" | cut -f1)"
  CHECKSUM="$(printf '%s' "$line" | cut -f2)"
}

resolve_latest() {
  local latest_reason="the repository has no designated latest release"
  local latest_tag=""
  local latest_line=""

  if api_get "repos/$REPO/releases/latest"; then
    latest_tag="$(printf '%s' "$API_BODY" | jq -r '.tag_name // empty')"
    if ! [[ "$latest_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
      latest_reason="release tag '$latest_tag' cannot be represented in an asset filename"
    elif [ "$(printf '%s' "$API_BODY" | jq -r '.draft == false')" = "true" ] && \
       [ "$(printf '%s' "$API_BODY" | jq -r '.prerelease == false')" = "true" ]; then
      ARCHIVE="${NAME}_${latest_tag}_${SUFFIX}"
      latest_line="$(select_asset "$API_BODY" "$ARCHIVE")"
      if [ -z "$latest_line" ]; then
        latest_reason="release '$latest_tag' does not contain '$ARCHIVE'"
      elif ! valid_asset_line "$latest_line"; then
        latest_reason="release asset '$ARCHIVE' has no published SHA-256 digest"
      else
        VERSION="$latest_tag"
        ASSET_API_URL="$(printf '%s' "$latest_line" | cut -f1)"
        CHECKSUM="$(printf '%s' "$latest_line" | cut -f2)"
        return
      fi
    else
      latest_reason="the designated latest release is a draft or prerelease"
    fi
  elif [ "$API_STATUS" != "404" ]; then
    error "Could not query the latest release in '$REPO' from the GitHub API (status: $API_STATUS)"
    exit 1
  fi

  echo "::notice::Falling back from the designated latest release because $latest_reason"

  local page=1
  local count
  local page_candidates
  local candidates=""
  while :; do
    if ! api_get "repos/$REPO/releases?per_page=100&page=$page"; then
      case "$API_STATUS" in
        404) error "Repository '$REPO' was not found. $TOKEN_HINT" ;;
        401|403) error "The GitHub API refused the request to list releases in '$REPO' (status: $API_STATUS). $TOKEN_HINT" ;;
        *) error "Could not list releases in '$REPO' from the GitHub API (status: $API_STATUS)" ;;
      esac
      exit 1
    fi
    count="$(printf '%s' "$API_BODY" | jq 'length')"
    page_candidates="$(printf '%s' "$API_BODY" | jq -c --arg name "$NAME" --arg suffix "$SUFFIX" '
      .[]
      | select(.draft == false and .prerelease == false)
      | select(.tag_name | test("^[A-Za-z0-9][A-Za-z0-9._+-]*$"))
      | . as $release
      | ($name + "_" + $release.tag_name + "_" + $suffix) as $want
      | $release.assets[]?
      | select(.name == $want and ((.digest // "") | test("^sha256:[0-9A-Fa-f]{64}$")))
      | {tag: $release.tag_name, published: $release.published_at, url: .url, digest: .digest}')"
    if [ -n "$page_candidates" ]; then
      candidates="${candidates}${page_candidates}"$'\n'
    fi
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done

  # Order by version, not by publication date: a patch backported to an older
  # line is published after the newer line's release, and picking by date would
  # hand back the older binary. Tags that are not version-shaped cannot be
  # compared that way, so those repos fall back to the newest published.
  local best_line
  best_line="$(printf '%s' "$candidates" | jq -s -r '
    def pad3: if length >= 3 then . else . + [range(3 - length) | 0] end;
    def semver_key:
      (capture("^v?(?<core>[0-9]+(\\.[0-9]+)*)(?:[-+](?<pre>.*))?$") // null)
      | if . == null then null
        else
          [ (.core | split(".") | map(tonumber) | pad3),
            (if (.pre // "") == "" then 1 else 0 end),
            (.pre // "") ]
        end;
    map(. + {key: (.tag | semver_key)})
    | if length == 0 then empty
      else
        (map(select(.key != null))) as $versioned
        | (if ($versioned | length) > 0 then ($versioned | max_by(.key)) else max_by(.published) end)
        | [.tag, .url, .digest]
        | @tsv
      end')"

  if [ -z "$best_line" ]; then
    error "No stable, non-draft release of '$REPO' contains a verifiable '${NAME}_<version>_${SUFFIX}' asset"
    exit 1
  fi
  VERSION="$(printf '%s' "$best_line" | cut -f1)"
  ASSET_API_URL="$(printf '%s' "$best_line" | cut -f2)"
  CHECKSUM="$(printf '%s' "$best_line" | cut -f3)"
  ARCHIVE="${NAME}_${VERSION}_${SUFFIX}"
}

if [ -n "$VERSION" ]; then
  resolve_pinned
else
  resolve_latest
fi

CHECKSUM="${CHECKSUM#sha256:}"
CHECKSUM="$(printf '%s' "$CHECKSUM" | tr '[:upper:]' '[:lower:]')"
if [ -z "$INSTALL_DIRECTORY" ]; then
  if [ "$OS" = "windows" ]; then
    INSTALL_DIRECTORY="/usr/bin"
  else
    INSTALL_DIRECTORY="/usr/local/bin"
  fi
fi

CACHE_KEY="${PREFIX}-${REPO}-${NAME}-${VERSION}-${OS}-${ARCH}-${CHECKSUM}"
if [ "${#CACHE_KEY}" -gt 512 ]; then
  error "The generated cache key is longer than GitHub Actions' 512-character limit; use a shorter prefix"
  exit 1
fi

echo "repo=$REPO"
echo "version=$VERSION"
echo "archive=$ARCHIVE"
echo "checksum=sha256:$CHECKSUM"
echo "cache-key=$CACHE_KEY"
echo "install-directory=$INSTALL_DIRECTORY"

{
  echo "archive=$ARCHIVE"
  echo "asset-api-url=$ASSET_API_URL"
  echo "checksum=$CHECKSUM"
  echo "cache-key=$CACHE_KEY"
  echo "install-directory=$INSTALL_DIRECTORY"
} >> "$GITHUB_OUTPUT"
