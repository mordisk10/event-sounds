# Changelog

All notable changes to Fancy Event Sounds are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Plugin icon (`META-INF/pluginIcon.svg`), so the plugin shows its logo in the
  Marketplace and in the IDE's plugin list instead of a generic placeholder.
- Unit test suite covering sound resolution, settings defaults, and the
  integrity of the bundled audio files.
- GitHub Actions workflow that compiles, tests, validates and packages the
  plugin on every push, publishing the installable zip as a run artifact.
- Manually triggered publish workflow with a dry-run mode, authenticating via a
  Marketplace permanent token.
- Full plugin description and per-version change notes, which are what the
  Marketplace listing renders.

### Changed
- Custom sound paths now fall back to the bundled sound when the file is
  unreadable, not only when it is missing or is a directory.
- Build configuration reads its version and platform coordinates from
  `gradle.properties`.

### Fixed
- Log messages and the audio thread name printed literal `$customPath` and
  `$name` instead of their values, from over-escaped string templates.
- A failed or finished player is now closed, and the reference cleared, instead
  of being left open.
- A missing bundled resource produced a `NullPointerException`; it is now
  reported in the IDE log and the event stays silent.
- `gradlew` was committed without its executable bit, so the documented
  `./gradlew` commands failed on Linux and macOS.

## [1.0.1]

### Added
- Settings screen under **Tools → Event Sounds**.
- Per-event enable/disable toggles.
- Custom `.mp3` selection per event, with a fallback to the bundled sound.

### Changed
- Rebuilt against the 2023.2 platform (build 232 and newer).

## [1.0.0]

### Added
- First release: sounds for run configurations that start and that fail to start.

[Unreleased]: https://github.com/mordisk10/event-sounds/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/mordisk10/event-sounds/releases/tag/v1.0.1
[1.0.0]: https://github.com/mordisk10/event-sounds/releases/tag/v1.0.0
