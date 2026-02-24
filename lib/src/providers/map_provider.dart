/// Configuration provider that loads from a `Map<String, dynamic>`.
library;

import '../abstractions/configuration_provider.dart';
import '../abstractions/configuration_source.dart';
import '../core/configuration_path.dart';
import '../reload/change_token.dart';
import '../utils/key_normalizer.dart';

/// A [ConfigurationProvider] that loads configuration from a nested
/// `Map<String, dynamic>`.
///
/// The map is recursively flattened into colon-separated keys:
///
/// ```
/// {'database': {'host': 'localhost', 'port': 5432}}
///   → database:host = 'localhost'
///   → database:port = '5432'
/// ```
///
/// Leaf values are converted to strings with `.toString()`.  `null` leaf
/// values are stored as `null`.  Lists are indexed:
///
/// ```
/// {'servers': ['a', 'b']}
///   → servers:0 = 'a'
///   → servers:1 = 'b'
/// ```
///
/// This provider does not support live reload; [getReloadToken] returns a
/// [NeverChangeToken].
final class MapConfigurationProvider extends ConfigurationProvider {
  /// Creates a provider from a nested [map].
  MapConfigurationProvider({required Map<String, dynamic> map}) : _map = map;

  final Map<String, dynamic> _map;

  @override
  void load() {
    data.clear();
    _flatten(_map, '');
  }

  @override
  ChangeToken getReloadToken() => const NeverChangeToken();

  void _flatten(Object? node, String prefix) {
    if (node is Map<String, dynamic>) {
      for (final entry in node.entries) {
        final childPath = ConfigurationPath.combine(prefix, entry.key);
        _flatten(entry.value, childPath);
      }
    } else if (node is List<dynamic>) {
      for (var i = 0; i < node.length; i++) {
        final childPath = ConfigurationPath.combine(prefix, i.toString());
        _flatten(node[i], childPath);
      }
    } else {
      // Scalar — store as a string or null.
      data[KeyNormalizer.normalize(prefix)] = node?.toString();
    }
  }
}

/// A [ConfigurationSource] that produces a [MapConfigurationProvider].
///
/// Register via [ConfigurationBuilder.addMap]:
/// ```dart
/// builder.addMap({
///   'database': {'host': 'localhost', 'port': 5432},
///   'logging': {'level': 'info'},
/// });
/// ```
final class MapConfigurationSource implements ConfigurationSource {
  /// Creates a source from [map].
  const MapConfigurationSource({required Map<String, dynamic> map})
      : _map = map;

  final Map<String, dynamic> _map;

  @override
  ConfigurationProvider build() => MapConfigurationProvider(map: _map);
}
