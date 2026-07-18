# Download IPFS Distribution Action

The action downloads an IPFS distribution from [GitHub releases](https://github.com/ipfs/kubo/releases) and puts it on `PATH`.

## How it works

1. The distribution `name` is mapped to a GitHub `owner/repo` (see [`distributions.json`](distributions.json)); the `github-repo` input overrides the map.
2. When `version` is empty, GitHub's designated latest stable, non-draft release is used if it ships a verifiable binary for the runner. If that release is incomplete, the newest published stable release with a matching binary and digest is used instead.
3. The asset name is built from the version, OS and arch (`<name>_<version>_<os>-<arch>.tar.gz`, or `.zip` on windows); there is no manifest to fetch.
4. The archive is restored from cache first; a hit skips the download. It is checksum-verified on every run, so a corrupt download or a tampered cache entry is caught.

Each download is verified against the release API's `sha256` digest; a missing or mismatched checksum fails the action. GitHub began computing these digests on [3 June 2025](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/), so releases published before then carry no digest and are unsupported. For kubo this means `v0.35.0` and older; use `v0.36.0` or newer.

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| name | Name of the distribution to download | kubo |
| version | Version of the distribution to download | *latest stable, non-draft release that ships a verifiable binary* |
| github-repo | GitHub `owner/repo` hosting the release binaries; overrides the built-in map (set it for distributions not in the map or to use a mirror) | *from [`distributions.json`](distributions.json)* |
| github-token | Token used to read release metadata and assets. The default token works for public repositories and the workflow repository; pass a PAT or GitHub App token with `Contents: read` for another private repository | `github.token` |
| working-directory | Directory where the action is going to be performed; the downloaded artifacts are cleaned up afterwards | runner.temp |
| install-directory | Directory where the executable is going to be copied | **linux, macos:** /usr/local/bin; **windows:** /usr/bin |
| cache | Whether the resolved archive is cached and restored before downloading | true |
| prefix | Prefix for the cache key | download-ipfs-distribution-action |

## Outputs

| Name | Description | Example |
| --- | --- | --- |
| executable | The name of the executable | ipfs |
| executables | The names of all the executables | ["ipfs"] |
| cache-hit | Whether the archive was restored from cache instead of downloaded | true |

## Caching

Caching is cache-first: before any download the archive is restored from the GitHub Actions cache, and a cache hit skips the download. The archive is still verified on every run, so a tampered cache entry is caught rather than trusted. The version and digest are resolved on every run, so a moving `latest` never serves a stale binary and a re-uploaded release asset gets a new cache entry. The key is `<prefix>-<repo>-<name>-<version>-<os>-<arch>-<sha256>`. Set `cache: false` to always download.

## Example

```yaml
- uses: ipfs/download-ipfs-distribution-action@v2
  with:
    name: kubo
- run: ipfs --help
  shell: bash
```

Download a distribution from an alternative repo (e.g. a fork, for testing):

```yaml
- uses: ipfs/download-ipfs-distribution-action@v2
  with:
    name: kubo
    github-repo: my-org/kubo
- run: ipfs --help
  shell: bash
```

### Private release repository

The job's default `GITHUB_TOKEN` is limited to the repository containing the workflow. To download from another private repository, pass a fine-grained PAT or GitHub App token that has `Contents: read` access to the release repository:

```yaml
- uses: ipfs/download-ipfs-distribution-action@v2
  with:
    name: kubo
    github-repo: my-org/private-kubo
    github-token: ${{ secrets.RELEASES_TOKEN }}
```

The token is sent only to GitHub's release metadata and release asset API endpoints. It is not written to action outputs, cache keys, or logs.

## Upgrading from v1

Version 2 is opt-in. The `v1` tag remains on `v1.4.2`; change the action reference to `@v2` only after checking the distribution name and pinned version.

| Distribution | First supported stable version in v2 |
| --- | --- |
| `kubo` | `v0.36.0` |
| `ipget` | `v0.13.1` |
| `ipfs-cluster-ctl`, `ipfs-cluster-follow`, `ipfs-cluster-service` | `v1.1.6` |

- Change the legacy `go-ipfs` name to `kubo`.
- Assets without a GitHub-provided SHA-256 digest are unsupported. Upgrade an older pin or remain on `@v1` temporarily.
- Distributions not listed in [`distributions.json`](distributions.json) need a conforming GitHub release repository supplied through `github-repo`; otherwise use a different installer.
- `cache-hit` now reports an ordinary cache restore. Existing v1 caches are ignored by the new repository-and-digest-aware keys and do not need to be deleted.
- Release metadata is required even on a cache hit. If the GitHub API is unavailable, the action fails closed rather than installing an archive it cannot verify against current metadata.
