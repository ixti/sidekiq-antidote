# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [1.1.0] - 2024-11-22

### Added

- Add Ruby-3.3 support
- Add Sidekiq-7.3 support

### Changed

- Do not mutate Remedy upon refresher execution


## [1.0.0] - 2023-12-10

### Changed

- Improve documentation and web UI

### Removed

- (BREAKING) Remove `Sidekiq::Antidote::Config#key_prefix`
- (BREAKING) Drop Sidekiq 7.0 support
- (BREAKING) Drop Sidekiq 7.1 support


## [1.0.0.alpha.1] - 2023-12-01

### Added

- Initial release.


[unreleased]: https://github.com/ixti/sidekiq-pauzer/compare/v1.0.0...main
[1.0.0]: https://github.com/ixti/sidekiq-pauzer/compare/v1.0.0.alpha.1...v1.0.0
[1.0.0.alpha.1]: https://github.com/ixti/sidekiq-antidote/tree/v1.0.0.alpha.1
