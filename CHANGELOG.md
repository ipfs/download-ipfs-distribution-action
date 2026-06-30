# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased
### Added
- `github-repo` input to override the built-in distribution-to-repo map (`distributions.json`) for distributions not in the map or to use a mirror

### Changed
- release binaries are fetched from GitHub releases
- when `version` is empty, resolve to the latest non-prerelease release that actually ships a binary for the runner; a newer release with no (or non-conforming) assets is skipped
- checksums come from the release API `digest` (sha256); the archive is verified on every run, including cache hits, and a missing or mismatched checksum fails the action. Releases predating GitHub's release-asset digests (2025-06-03) carry no digest and are unsupported (for kubo, `v0.35.0` and older)
- caching is now cache-first: the archive is restored before any download, keyed on the resolved concrete version (`<prefix>-<name>-<version>-<os>-<arch>`); a cache hit skips the download but the archive is still verified
- `cache-hit` output now reports whether the archive was restored from cache instead of downloaded

### Removed
- dropped the `dist.ipfs.tech` download path; a distribution must now have a GitHub release (mapped in `distributions.json` or set via the `github-repo` input)

## [1.4.2] - 2026-04-11
### Changed
- updated `actions/cache/restore` and `actions/cache/save` actions to v5

## [1.4.1] - 2025-02-05
### Changed
- remove the unused `retention-days` input from the `actions/cache/save` step

## [1.4.0] - 2025-02-05
### Changed
- default `name` changed from `go-ipfs` to `kubo` (see [ipfs/kubo#8959](https://github.com/ipfs/kubo/issues/8959) for wider context)
- the fallback cache is now backed by the GitHub Actions cache instead of job artifacts

## [1.3.0] - 2025-01-24
### Added
- a prefix input which allows controlling the GitHub Actions artifacts name prefixes

### Changed
- update the upload-artifact action to v4

## [1.2.3] - 2023-08-11
### Changed
- use sudo to cp executables to install directory

## [1.2.2] - 2023-02-08
### Fixed
- stop using deprecated set-output command

## [1.2.1] - 2022-08-29
### Changed
- distribution source from *dist.ipfs.io* to [dist.ipfs.tech](https://dist.ipfs.tech)

## [1.2.0] - 2022-03-23
### Added
- cache support for `versions` and `dist.json`

### Changed
- cache to work only as a fallback

## [1.1.1] - 2022-03-07
### Changed
- the tool used for extracting ZIP files from `unzip` to `7z`

## [1.1.0] - 2022-02-03
### Added
- archive caching controlled by boolean input `cache`

### Changed
- `working-directory` default from current dir to temp dir

## [1.0.2] - 2021-12-16
### Added
- 5 retries to download requests made with curl

### Fixed
- working-directory in final step which removes files and directories created during execution

## [1.0.1] - 2021-12-15
### Added
- sha512sum verification of downloaded distributions

## [1.0.0] - 2021-12-14
### Added
- action that downloads a distribution from [dist.ipfs.io](https://dist.ipfs.io) and puts it on `PATH`
