# davianspace_configuration

A production-ready, dependency-free configuration library for Dart and Flutter — modelled after `Microsoft.Extensions.Configuration` and adapted idiomatically for Dart.

Compose configuration from multiple sources (JSON files, environment variables, in-memory maps, and custom providers), read values through a unified hierarchical API, and react to runtime changes via a lightweight change-token notification system.

---

## Features

- **Hierarchical key–value storage** — colon-separated paths (`database:host`), case-insensitive keys
- **Multiple built-in providers**
  - `MemoryConfigurationProvider` — flat `Map<String, String?>`
  - `MapConfigurationProvider` — recursive `Map<String, dynamic>` and `List` flattening
  - `EnvironmentConfigurationProvider` — optional prefix filtering, `__`→`:` key mapping
  - `JsonStringConfigurationProvider` — parse any JSON string (all platforms)
  - `JsonFileConfigurationProvider` — native (VM/AOT) only, opt-in `reloadOnChange`
- **Provider precedence** — last-added source wins on conflicting keys
- **Section access** — `getSection('database')` returns a scoped `ConfigurationSection`
- **Required-value enforcement** — `getRequired('key')` throws a descriptive `StateError` when absent
- **Change-token reload** — subscribe before a reload, receive a synchronous callback after
- **`ConfigurationManager`** — mutable live configuration: add providers after initial build with immediate effect
- **Zero runtime dependencies** — pure Dart, no reflection
- **Full platform support** — file/env features use conditional imports; web falls back gracefully

---

## Installation

```yaml
dependencies:
  davianspace_configuration: ^1.0.0
```

---

## Quick start

```dart
import 'package:davianspace_configuration/davianspace_configuration.dart';

void main() {
  final config = ConfigurationBuilder()
      .addMap({
        'app': {'name': 'Orders', 'version': '1.0.0'},
        'database': {'host': 'localhost', 'port': 5432},
      })
      .addEnvironmentVariables(prefix: 'APP_')
      .build();

  print(config['app:name']);        // Orders
  print(config['database:host']);   // localhost (or APP__DATABASE__HOST if set)
}
```

---

## Providers

### In-memory (flat map)

```dart
ConfigurationBuilder()
    .addInMemory({
      'database:host': 'localhost',
      'database:port': '5432',
    })
    .build();
```

### In-memory (nested map / list)

```dart
ConfigurationBuilder()
    .addMap({
      'database': {'host': 'localhost', 'port': 5432},
      'features': ['darkMode', 'betaSearch'],
    })
    .build();

// features:0 → darkMode, features:1 → betaSearch
```

### Environment variables

```dart
// All environment variables.
ConfigurationBuilder().addEnvironmentVariables().build();

// Only variables starting with APP_, prefix stripped, __ → :.
// APP__DATABASE__HOST=db.prod sets database:host.
ConfigurationBuilder().addEnvironmentVariables(prefix: 'APP_').build();
```

### JSON string

```dart
ConfigurationBuilder()
    .addJsonString('{"database":{"host":"localhost"}}')
    .build();
```

### JSON file (native only)

```dart
ConfigurationBuilder()
    .addJsonFile('appsettings.json')
    .addJsonFile('appsettings.production.json', optional: true)
    .addJsonFile('appsettings.local.json', optional: true, reloadOnChange: true)
    .build();
```

---

## Hierarchical access

Keys are colon-separated and case-insensitive. `getSection()` returns a
`ConfigurationSection` scoped to the given path — nested keys are relative.

```dart
final config = ConfigurationBuilder()
    .addMap({'database': {'host': 'localhost', 'pool': {'maxSize': 10}}})
    .build();

final db = config.getSection('database');
print(db['host']);         // localhost
print(db['pool:maxSize']); // 10
print(db.path);            // database
```

---

## Required values

```dart
// Throws StateError: "Required configuration key 'api:key' not found."
final apiKey = config.getRequired('api:key');
```

---

## Provider precedence

Sources are evaluated in registration order.  The **last-added source wins**
on conflicting keys — mirror of Microsoft.Extensions.Configuration conventions.

```dart
final config = ConfigurationBuilder()
    .addInMemory({'database:host': 'localhost'})      // tier 1 — base
    .addJsonString('{"database":{"host":"prod.db"}}') // tier 2 — overrides tier 1
    .addEnvironmentVariables(prefix: 'APP_')          // tier 3 — overrides all
    .build();
// database:host → 'prod.db' unless APP__DATABASE__HOST is set.
```

---

## Change tokens and reload

```dart
final config = ConfigurationBuilder()
    .addJsonFile('appsettings.json', reloadOnChange: true)
    .build();

// Register a callback before the reload fires.
config.getReloadToken().registerCallback(() {
  print('Configuration reloaded');
});

// To force a manual reload:
config.reload();
```

`reloadOnChange: true` on `JsonFileConfigurationProvider` watches the file via
`dart:io`'s `File.watch()` and triggers an automatic reload.

---

## ConfigurationManager

`ConfigurationManager` acts as both builder and live configuration.
Adding a provider takes effect immediately — useful for incrementally
loading configuration on startup.

```dart
final manager = ConfigurationManager()
  ..addInMemory({'feature:newUi': 'false'});

// … later, after fetching remote flags …
manager.addMap({'feature': {'newUi': 'true', 'exportCsv': 'true'}});

print(manager['feature:newUi']);      // true  (new provider wins)
print(manager['feature:exportCsv']); // true

// Snapshot the current state as a static ConfigurationRoot.
final snapshot = manager.buildSnapshot();
```

---

## Custom providers

Implement `ConfigurationSource` and `ConfigurationProvider`:

```dart
class VaultSource implements ConfigurationSource {
  @override
  ConfigurationProvider build() => VaultProvider();
}

class VaultProvider extends ConfigurationProvider {
  @override
  void load() {
    // Pull secrets from a vault and populate [data].
    data['api:key'] = Platform.environment['VAULT_API_KEY'];
  }
}

ConfigurationBuilder().add(VaultSource()).build();
```

---

## API reference

| Class | Description |
|---|---|
| `ConfigurationBuilder` | Fluent builder — calls `build()` to produce a `ConfigurationRoot` |
| `ConfigurationRoot` | Merged immutable configuration; implements `Configuration` |
| `ConfigurationManager` | Mutable live configuration — add providers post-build |
| `ConfigurationSection` | Scoped view into a sub-tree of the configuration |
| `ConfigurationProvider` | Abstract base class for all providers |
| `ConfigurationSource` | Factory interface — `ConfigurationProvider build()` |
| `ConfigurationPath` | Path helper — `combine`, `getSegments`, `getSectionKey` |
| `KeyNormalizer` | Case-insensitive key normalization |
| `ChangeToken` | Reload notification token |
| `ReloadToken` | Single-use, manually-triggered change token |
| `ChangeNotifier` | Rotating token manager (used by `ConfigurationRoot`) |

---

## License

MIT — see [LICENSE](LICENSE)
