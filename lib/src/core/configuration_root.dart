/// The merged, read-write configuration root built by [ConfigurationBuilder].
library;

import '../abstractions/configuration.dart';
import '../abstractions/configuration_provider.dart';
import '../core/configuration_path.dart';
import '../reload/change_notifier.dart';
import '../reload/change_token.dart';
import '../utils/key_normalizer.dart';

/// The merged view of all registered [ConfigurationProvider]s.
///
/// [ConfigurationRoot] is produced by [ConfigurationBuilder.build].  It
/// queries providers in **reverse registration order** (last-added wins) so
/// that environment-specific overrides consistently take precedence over base
/// JSON files.
///
/// Reload events from any provider are aggregated through an internal
/// [ChangeNotifier] and surfaced to subscribers via [getReloadToken].
///
/// ```dart
/// final root = ConfigurationBuilder()
///     .addInMemory({'app:name': 'Orders'})
///     .addEnvironmentVariables()
///     .build();
///
/// final name = root['app:name'];
/// ```
final class ConfigurationRoot implements Configuration {
  /// Creates a [ConfigurationRoot] from a list of pre-built providers.
  ///
  /// All providers are loaded immediately.  Call [reload] explicitly to
  /// trigger subsequent reloads, or rely on provider-level reload tokens.
  ConfigurationRoot(List<ConfigurationProvider> providers)
      : _providers = List.unmodifiable(providers) {
    for (final p in _providers) {
      p.load();
      _wireReloadCallback(p);
    }
  }

  final List<ConfigurationProvider> _providers;
  final ChangeNotifier _notifier = ChangeNotifier();

  // ── Configuration interface ─────────────────────────────────────────────

  @override
  String? operator [](String key) {
    final normalized = KeyNormalizer.normalize(key);
    // Iterate in reverse: the last-added provider wins.
    for (var i = _providers.length - 1; i >= 0; i--) {
      final (found, value) = _providers[i].tryGet(normalized);
      if (found) return value;
    }
    return null;
  }

  @override
  void operator []=(String key, String? value) {
    final normalized = KeyNormalizer.normalize(key);
    // Write to the last provider that already owns the key, otherwise write
    // to the last provider overall (which has the highest precedence).
    for (var i = _providers.length - 1; i >= 0; i--) {
      if (_providers[i].data.containsKey(normalized)) {
        _providers[i].set(normalized, value);
        return;
      }
    }
    if (_providers.isNotEmpty) {
      _providers.last.set(normalized, value);
    }
  }

  @override
  ConfigurationSection getSection(String key) =>
      _ConfigurationSection(this, KeyNormalizer.normalize(key));

  @override
  Iterable<ConfigurationSection> getChildren() => _childrenOf('');

  @override
  String getRequired(String key) {
    final value = this[key];
    if (value == null) {
      throw StateError(
        'Configuration value for key "$key" is required but was not found.',
      );
    }
    return value;
  }

  // ── Change tracking ────────────────────────────────────────────────────

  /// Returns a [ChangeToken] that fires whenever any provider reloads.
  ///
  /// Obtain the token **before** the change to be sure the registration
  /// is in place:
  ///
  /// ```dart
  /// root.getReloadToken().registerCallback(() => print('config reloaded'));
  /// ```
  ChangeToken getReloadToken() => _notifier.getChangeToken();

  /// Forces all providers to reload synchronously.
  void reload() {
    for (final p in _providers) {
      p.load();
    }
    _notifier.onReload();
  }

  // ── Internal helpers ────────────────────────────────────────────────────

  /// Returns all direct child sections under [parentPath].
  Iterable<ConfigurationSection> _childrenOf(String parentPath) {
    final keys = <String>[];
    // Iterate providers in REVERSE so high-precedence providers contribute
    // their keys first; each provider only adds keys not already seen.
    for (var i = _providers.length - 1; i >= 0; i--) {
      final childKeys = _providers[i]
          .getChildKeys(keys, parentPath.isEmpty ? null : parentPath);
      for (final k in childKeys) {
        if (!keys.contains(k)) keys.add(k);
      }
    }
    return keys.map((k) {
      final childPath = ConfigurationPath.combine(parentPath, k);
      return _ConfigurationSection(this, childPath);
    });
  }

  void _wireReloadCallback(ConfigurationProvider provider) {
    provider.getReloadToken().registerCallback(() {
      _notifier.onReload();
      // Re-wire for the next reload cycle.
      _wireReloadCallback(provider);
    });
  }
}

// ── ConfigurationSection implementation ─────────────────────────────────────

final class _ConfigurationSection implements ConfigurationSection {
  _ConfigurationSection(this._root, this._path);

  final ConfigurationRoot _root;
  final String _path;

  @override
  String get key => ConfigurationPath.getSectionKey(_path);

  @override
  String get path => _path;

  @override
  String? get value => _root[_path];

  @override
  set value(String? val) => _root[_path] = val;

  @override
  String? operator [](String key) =>
      _root[ConfigurationPath.combine(_path, key)];

  @override
  void operator []=(String key, String? value) =>
      _root[ConfigurationPath.combine(_path, key)] = value;

  @override
  ConfigurationSection getSection(String key) =>
      _root.getSection(ConfigurationPath.combine(_path, key));

  @override
  Iterable<ConfigurationSection> getChildren() => _root._childrenOf(_path);

  @override
  String getRequired(String key) {
    final fullKey = ConfigurationPath.combine(_path, key);
    final val = _root[fullKey];
    if (val == null) {
      throw StateError(
        'Configuration value for key "$fullKey" is required but was not found.',
      );
    }
    return val;
  }
}
