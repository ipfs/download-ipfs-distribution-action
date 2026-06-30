# Download IPFS Distribution Action

The action downloads an IPFS distribution from [GitHub releases](https://github.com/ipfs/kubo/releases) and puts it on `PATH`.

## How it works

1. The distribution `name` is mapped to a GitHub `owner/repo` (see [`distributions.json`](distributions.json)); the `github-repo` input overrides the map.
2. When `version` is empty, the latest non-prerelease release that actually ships a binary for the runner is used. A newer release with no (or non-conforming) assets is skipped, so the action never resolves to a version GitHub cannot serve.
3. The asset name is built from the version, OS and arch (`<name>_<version>_<os>-<arch>.tar.gz`, or `.zip` on windows); there is no manifest to fetch.
4. The archive is restored from cache first; a hit skips the download. It is checksum-verified on every run, so a corrupt download or a tampered cache entry is caught.

Each download is verified against the release API's `sha256` digest; a missing or mismatched checksum fails the action. GitHub began computing these digests on [3 June 2025](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/), so releases published before then carry no digest and are unsupported. For kubo this means `v0.35.0` and older; use `v0.36.0` or newer.

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| name | Name of the distribution to download | kubo |
| version | Version of the distribution to download | *latest release that ships binaries* |
| github-repo | GitHub `owner/repo` hosting the release binaries; overrides the built-in map (set it for distributions not in the map or to use a mirror) | *from [`distributions.json`](distributions.json)* |
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

Caching is cache-first: before any download the archive is restored from the GitHub Actions cache, and a cache hit skips the download. The archive is still verified on every run, so a tampered cache entry is caught rather than trusted. The version is still resolved on every run (a cheap release lookup), so the cache key always pins a concrete version, never `latest`, and a moving `latest` never serves a stale binary. The key is `<prefix>-<name>-<version>-<os>-<arch>`. Set `cache: false` to always download.

## Example

```yaml
- uses: ipfs/download-ipfs-distribution-action@v1
  with:
    name: kubo
- run: ipfs --help
  shell: bash
```

Download a distribution from an alternative repo (e.g. a fork, for testing):

```yaml
- uses: ipfs/download-ipfs-distribution-action@v1
  with:
    name: kubo
    github-repo: my-org/kubo
- run: ipfs --help
  shell: bash
```
