# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2025-07-19

### Added

- `ConfigurationBuilder` — fluent builder composing multiple sources into a single `ConfigurationRoot`.
- `ConfigurationRoot` — merged configuration root with reverse-precedence provider iteration.
- `ConfigurationManager` — mutable live configuration; adding a provider takes effect immediately.
- `ConfigurationSection` — scoped, path-aware view into a configuration sub-tree.
- `MemoryConfigurationProvider` / `MemoryConfigurationSource` — flat `Map<String, String?>` provider.
- `MapConfigurationProvider` / `MapConfigurationSource` — recursive `Map<String, dynamic>` and `List` flattening.
- `EnvironmentConfigurationProvider` / `EnvironmentConfigurationSource` — optional prefix filtering with `__`→`:` key mapping; web stub returns empty map.
- `JsonStringConfigurationProvider` / `JsonStringConfigurationSource` — all-platform JSON string parsing.
- `JsonFileConfigurationProvider` / `JsonFileConfigurationSource` — native file loading with optional `reloadOnChange` support via `dart:io` file watching.
- `ConfigurationPath` — colon-separated path utilities (`combine`, `combineAll`, `getSectionKey`, `getParentPath`, `getSegments`).
- `KeyNormalizer` — lowercase key normalisation and equality helpers.
- `ChangeToken` / `TokenRegistration` / `NeverChangeToken` — reload notification abstractions.
- `ReloadToken` — single-use, synchronously-firing change token.
- `ChangeNotifier` — rotating reload-token manager consumed by `ConfigurationRoot`.
- Zero runtime dependencies.
- 80 unit tests, all passing.
