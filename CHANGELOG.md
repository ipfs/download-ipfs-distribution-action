# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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
