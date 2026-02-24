/// Abstract base class for all configuration providers.
library;

import '../core/configuration_path.dart';
import '../reload/change_token.dart';
import '../reload/reload_token.dart';
import '../utils/key_normalizer.dart';

/// Base class for all configuration data providers.
///
/// Each provider owns a flat `Map<String, String?>` named [data] keyed by
/// normalized, colon-separated paths.  Hierarchical JSON, nested maps, and
/// environment variables are all flattened into this map before storage.
///
/// Subclasses **must** override [load] to populate [data].  Override
/// [getReloadToken] when the provider supports live reload.
///
/// ### Key normalization
/// All keys in [data] **must** be normalized (lowercase) before insertion.
/// Use [KeyNormalizer.normalize] or call [normalizeKey] from constructors.
///
/// ### Reload
/// When a provider detects a change it should:
/// 1. Re-populate [data] with fresh values.
/// 2. Call [onReload] which rotates [_reloadToken] and fires the previous one.
///
/// ```dart
/// class MyProvider extends ConfigurationProvider {
///   @override
///   void load() {
///     data.clear();
///     data['app:name'] = 'MyApp';
///   }
/// }
/// ```
abstract class ConfigurationProvider {
  /// Creates a provider with an empty data map and a fresh reload token.
  ConfigurationProvider() : _reloadToken = ReloadToken();

  /// The flat key-value store for this provider.
  ///
  /// Keys are normalized (lowercase, colon-separated).  Subclasses populate
  /// this map inside [load] and may update it inside a reload cycle.
  final Map<String, String?> data = {};

  ReloadToken _reloadToken;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Retrieves the value for [key], returning `null` when absent.
  ///
  /// [key] is normalized before lookup.
  String? get(String key) => data[KeyNormalizer.normalize(key)];

  /// Sets [value] at [key].
  ///
  /// [key] is normalized before storage.
  void set(String key, String? value) {
    data[KeyNormalizer.normalize(key)] = value;
  }

  /// Attempts to retrieve the value for [key].
  ///
  /// Returns a record `(true, value)` when found, or `(false, null)` when
  /// absent.
  (bool found, String? value) tryGet(String key) {
    final normalized = KeyNormalizer.normalize(key);
    final contains = data.containsKey(normalized);
    return (contains, contains ? data[normalized] : null);
  }

  /// Loads or reloads configuration data into [data].
  ///
  /// Called once during startup and again whenever the configuration source
  /// signals a change.  Subclasses **must** clear and repopulate [data].
  void load();

  /// Returns the current reload [ChangeToken].
  ///
  /// Callers should obtain the token **before** registering callbacks so the
  /// registration is in place before the next reload signal.  The default
  /// implementation returns a [NeverChangeToken] indicating this provider
  /// does not support live reload.
  ChangeToken getReloadToken() => _reloadToken;

  /// Returns the direct child keys under [parentPath] that are not already
  /// present in [earlierKeys].
  ///
  /// Used by [ConfigurationRoot] when enumerating children so that providers
  /// are iterated in reverse precedence order and no key is returned twice.
  ///
  /// [parentPath] is the colon-separated prefix path.  Pass `null` or `''`
  /// to enumerate top-level keys.
  Iterable<String> getChildKeys(
    Iterable<String> earlierKeys,
    String? parentPath,
  ) {
    final prefix = parentPath != null && parentPath.isNotEmpty
        ? '${parentPath.toLowerCase()}${ConfigurationPath.separator}'
        : '';

    final result = <String>{};
    for (final key in data.keys) {
      if (prefix.isNotEmpty && !key.startsWith(prefix)) continue;
      final remainder = key.substring(prefix.length);
      final segEnd = remainder.indexOf(ConfigurationPath.separator);
      final segment = segEnd < 0 ? remainder : remainder.substring(0, segEnd);

      if (segment.isNotEmpty && !earlierKeys.contains(segment)) {
        result.add(segment);
      }
    }
    return result;
  }

  // ── Protected helpers ──────────────────────────────────────────────────────

  /// Rotates the reload token and fires change callbacks.
  ///
  /// Call this **after** repopulating [data] inside a reload cycle.
  void onReload() {
    final previous = _reloadToken;
    _reloadToken = ReloadToken();
    previous.notifyChanged();
  }

  /// Normalizes [key] for storage in [data].
  static String normalizeKey(String key) => KeyNormalizer.normalize(key);
}
