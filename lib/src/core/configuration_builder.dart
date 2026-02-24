/// The fluent builder that assembles a [ConfigurationRoot].
library;

import '../abstractions/configuration_provider.dart';
import '../abstractions/configuration_source.dart';
import '../providers/environment_provider.dart';
import '../providers/json_provider.dart';
import '../providers/map_provider.dart';
import '../providers/memory_provider.dart';
import 'configuration_root.dart';

/// Assembles a [ConfigurationRoot] from one or more [ConfigurationSource]s.
///
/// Sources are evaluated in registration order; the **last** source added
/// always wins when multiple sources define the same key.
///
/// ```dart
/// final config = ConfigurationBuilder()
///     .addInMemory({'app:name': 'Orders', 'app:version': '1.0'})
///     .addJsonFile('appsettings.json')
///     .addJsonFile('appsettings.production.json', optional: true)
///     .addEnvironmentVariables(prefix: 'APP_')
///     .build();
///
/// print(config['app:name']);
/// ```
final class ConfigurationBuilder {
  final List<ConfigurationSource> _sources = [];

  /// The read-only list of sources added so far.
  List<ConfigurationSource> get sources => List.unmodifiable(_sources);

  // ── Registration helpers ─────────────────────────────────────────────────

  /// Adds a [ConfigurationSource] directly.
  ///
  /// Call this method to integrate third-party or custom sources.
  ConfigurationBuilder add(ConfigurationSource source) {
    _sources.add(source);
    return this;
  }

  /// Adds key-value pairs from an in-memory [Map<String, String?>].
  ///
  /// Mutable changes to the resulting configuration do not propagate back
  /// to the original map.
  ///
  /// ```dart
  /// builder.addInMemory({'database:host': 'localhost', 'database:port': '5432'});
  /// ```
  ConfigurationBuilder addInMemory(Map<String, String?> initialData) {
    _sources.add(MemoryConfigurationSource(initialData: initialData));
    return this;
  }

  /// Adds a generic `Map<String, dynamic>` provider.
  ///
  /// Nested maps are flattened using colon-separated keys:
  /// `{'database': {'host': 'localhost'}}` → `{'database:host': 'localhost'}`.
  ///
  /// Non-string leaf values are converted with `.toString()`.
  ConfigurationBuilder addMap(Map<String, dynamic> map) {
    _sources.add(MapConfigurationSource(map: map));
    return this;
  }

  /// Adds a [JsonFileConfigurationSource] that loads from [filePath].
  ///
  /// When [optional] is `true` the provider is silently skipped when the
  /// file does not exist.  When [reloadOnChange] is `true` the provider
  /// watches the file for modifications and reloads automatically.
  ///
  /// > **Platform note**: file-system access requires a native platform
  /// > (VM, AOT, Flutter desktop / mobile).  Do not call this method when
  /// > targeting Dart web / WASM; use [addMap] or [addInMemory] instead.
  ConfigurationBuilder addJsonFile(
    String filePath, {
    bool optional = false,
    bool reloadOnChange = false,
  }) {
    _sources.add(
      JsonFileConfigurationSource(
        filePath: filePath,
        optional: optional,
        reloadOnChange: reloadOnChange,
      ),
    );
    return this;
  }

  /// Adds a [JsonStringConfigurationSource] that parses [jsonContent] directly.
  ///
  /// Useful for loading configuration from a network response, an embedded
  /// asset, or a test fixture without touching the file system.
  ConfigurationBuilder addJsonString(String jsonContent) {
    _sources.add(JsonStringConfigurationSource(jsonContent: jsonContent));
    return this;
  }

  /// Adds an [EnvironmentConfigurationSource].
  ///
  /// When [prefix] is provided only environment variables whose names start
  /// with `prefix` (case-insensitive) are included, and the prefix is
  /// stripped before the key is stored.  Double-underscores (`__`) in the
  /// variable name are converted to colon separators so
  /// `APP__DATABASE__HOST` maps to `database:host` (after prefix removal).
  ConfigurationBuilder addEnvironmentVariables({String prefix = ''}) {
    _sources.add(EnvironmentConfigurationSource(prefix: prefix));
    return this;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  /// Builds and returns a [ConfigurationRoot] from the registered sources.
  ///
  /// Each source's `build()` method is called to obtain a
  /// [ConfigurationProvider]; providers' [ConfigurationProvider.load] methods
  /// are then called in registration order.
  ConfigurationRoot build() {
    final providers = <ConfigurationProvider>[
      for (final source in _sources) source.build(),
    ];
    return ConfigurationRoot(providers);
  }
}
