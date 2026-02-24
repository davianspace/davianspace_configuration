# Contributing

Thank you for your interest in contributing to `davianspace_configuration`.

## Getting started

1. Fork the repository and create a feature branch from `master`.
2. Fetch dependencies:
   ```sh
   dart pub get
   ```
3. Run the full test suite before making changes:
   ```sh
   dart test
   ```
4. Run the analyzer to confirm a clean baseline:
   ```sh
   dart analyze
   ```

## Development guidelines

- **Dart SDK** ≥ 3.0.0 — avoid features that require a higher minimum.
- **Zero runtime dependencies** — the library must remain dependency-free.
  Dev dependencies (`lints`, `test`) are acceptable.
- **Strict analysis** — the project uses `package:lints/recommended.yaml` with
  additional strict rules.  All warnings are treated as errors in CI.  Run
  `dart analyze` before raising a PR and resolve every issue.
- **All-platform support** — any code that calls `dart:io` must use conditional
  imports with a web stub so the library compiles for Flutter web.
- **Test coverage** — every public API change must be accompanied by unit
  tests.  New providers require both happy-path and error-path tests.
- **Style** — follow standard Dart idioms.  Run `dart format .` before
  committing.

## Submitting a pull request

1. Ensure `dart test`, `dart analyze`, and `dart format --output=none --set-exit-if-changed .`
   all exit with code 0.
2. Write a clear, concise PR description explaining *what* changed and *why*.
3. Reference any related issues.
4. Keep PRs focused — one feature or fix per PR.

## Reporting issues

Open a GitHub issue with:
- A minimal reproducible example.
- The Dart SDK version (`dart --version`).
- The platform (VM, web, AOT).
- The observed and expected behaviour.

## Code of conduct

This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Please be respectful and constructive in all interactions.
