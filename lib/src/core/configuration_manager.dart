/// A combined configuration builder and live configuration root.
library;

import '../abstractions/configuration.dart';
import '../abstractions/configuration_provider.dart';
import '../abstractions/configuration_source.dart';
import '../providers/environment_provider.dart';
import '../providers/json_provider.dart';
import '../providers/map_provider.dart';
import '../providers/memory_provider.dart';
import '../reload/change_token.dart';
import 'configuration_builder.dart';
import 'configuration_root.dart';

/// A configuration that is both a builder and a live [Configuration].
///
/// [ConfigurationManager] is the recommended entry point for applications
/// that need to add or remove providers at runtime without rebuilding the
/// entire configuration.  Each call to [add] immediately builds and loads
/// the corresponding provider, making the new values available through the
/// same [Configuration] reference.
///
/// This is the Dart equivalent of .NET 6's `ConfigurationManager`.
///
/// ```dart
/// final manager = ConfigurationManager()
///   ..addInMemory({'app:name': 'Orders'})
///   ..addJsonFile('appsettings.json')
///   ..addEnvironmentVariables(prefix: 'APP_');
///
/// // Access values immediately — no separate build() call needed.
/// final host = manager['database:host'];
///
/// // Add providers at runtime:
/// manager.addInMemory({'feature:darkMode': 'true'});
/// final dark = manager['feature:darkMode']; // 'true'
/// ```
final class ConfigurationManager implements Configuration {
  /// Creates a [ConfigurationManager] with no initial providers.
  ///
  /// Add providers immediately via the fluent [add], [addInMemory], [addMap],
  /// [addJsonFile], [addJsonString], or [addEnvironmentVariables] methods.
  /// Each call takes effect immediately — no separate `build()` call is needed.
  ConfigurationManager();

  final List<ConfigurationProvider> _providers = [];
  late ConfigurationRoot _root = ConfigurationRoot(_providers);

  // ── Registration helpers (mirrors ConfigurationBuilder) ──────────────────

  /// Adds a [ConfigurationSource] and immediately loads its provider.
  ConfigurationManager add(ConfigurationSource source) {
    final provider = source.build();
    _providers.add(provider);
    _root = ConfigurationRoot(_providers);
    return this;
  }

  /// Adds key-value pairs from an in-memory [Map<String, String?>].
  ConfigurationManager addInMemory(Map<String, String?> initialData) =>
      add(MemoryConfigurationSource(initialData: initialData));

  /// Adds a generic nested `Map<String, dynamic>` — values are flattened.
  ConfigurationManager addMap(Map<String, dynamic> map) =>
      add(MapConfigurationSource(map: map));

  /// Adds a [JsonFileConfigurationSource].
  ///
  /// > **Platform note**: requires a native Dart/Flutter platform.
  ConfigurationManager addJsonFile(
    String filePath, {
    bool optional = false,
    bool reloadOnChange = false,
  }) =>
      add(
        JsonFileConfigurationSource(
          filePath: filePath,
          optional: optional,
          reloadOnChange: reloadOnChange,
        ),
      );

  /// Adds a [JsonStringConfigurationSource].
  ConfigurationManager addJsonString(String jsonContent) =>
      add(JsonStringConfigurationSource(jsonContent: jsonContent));

  /// Adds an [EnvironmentConfigurationSource].
  ConfigurationManager addEnvironmentVariables({String prefix = ''}) =>
      add(EnvironmentConfigurationSource(prefix: prefix));

  // ── Delegate Configuration to internal root ───────────────────────────────

  @override
  String? operator [](String key) => _root[key];

  @override
  void operator []=(String key, String? value) => _root[key] = value;

  @override
  ConfigurationSection getSection(String key) => _root.getSection(key);

  @override
  Iterable<ConfigurationSection> getChildren() => _root.getChildren();

  @override
  String getRequired(String key) => _root.getRequired(key);

  // ── Change tracking ───────────────────────────────────────────────────────

  /// Returns a [ChangeToken] that fires whenever any provider reloads.
  ChangeToken getReloadToken() => _root.getReloadToken();

  /// Forces all providers to reload synchronously.
  void reload() => _root.reload();

  /// Builds a static [ConfigurationRoot] snapshot from the current providers.
  ///
  /// Use this when you need to hand off an immutable view to a subsystem
  /// while continuing to modify the [ConfigurationManager] its providers.
  ConfigurationRoot buildSnapshot() => ConfigurationBuilder()
      .apply(_providers.map((p) => _ProviderSource(p)))
      .build();
}

// ── Internal helper ──────────────────────────────────────────────────────────

extension on ConfigurationBuilder {
  ConfigurationBuilder apply(Iterable<ConfigurationSource> sources) {
    for (final s in sources) {
      add(s);
    }
    return this;
  }
}

/// Wraps an already-built [ConfigurationProvider] as a [ConfigurationSource]
/// so it can be re-used in [ConfigurationBuilder.build].
final class _ProviderSource implements ConfigurationSource {
  const _ProviderSource(this._provider);
  final ConfigurationProvider _provider;

  @override
  ConfigurationProvider build() => _provider;
}
