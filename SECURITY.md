# Security policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✓         |

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

To report a security issue, email **security@davianspace.dev** with:

- A description of the vulnerability and its potential impact.
- Steps to reproduce or a minimal proof-of-concept.
- Any relevant version information (`dart --version`, package version).

You should receive an acknowledgement within 48 hours.  We aim to release a
patch within 14 days of confirming the issue.

## Scope

This library handles configuration values that may include secrets (API keys,
connection strings, passwords).  Security-relevant areas include:

- `JsonFileConfigurationProvider` — file I/O on the native platform.
- `EnvironmentConfigurationProvider` — reads `Platform.environment`.
- `JsonStringConfigurationProvider` — JSON parsing.

## Best practices for consumers

- **Never log configuration values** — they may contain secrets.
- **Use required-value enforcement** — call `getRequired()` for mandatory
  secrets so the application fails fast with a clear error rather than
  proceeding with an empty or default value.
- **Restrict file permissions** — ensure `appsettings.*.json` files containing
  secrets are not world-readable on shared hosts.
- **Prefer environment variables or a secrets manager** for production secrets
  over committing values to JSON files.
