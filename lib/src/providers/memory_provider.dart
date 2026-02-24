/// In-memory configuration provider and its associated source.
library;

import '../abstractions/configuration_provider.dart';
import '../abstractions/configuration_source.dart';
import '../reload/change_token.dart';
import '../utils/key_normalizer.dart';

/// A [ConfigurationProvider] backed by an in-memory [Map<String, String?>].
///
/// Values are populated at construction time from [initialData] and are
/// fully mutable via [ConfigurationProvider.set].  This provider is ideal
/// for:
/// - Default values that ship with an application.
/// - Test fixtures that must not touch the file system.
/// - Runtime overrides injected programmatically.
///
/// This provider does **not** support automatic reload because there is no
/// external data source to watch.  Its [getReloadToken] returns a
/// [NeverChangeToken].
///
/// ```dart
/// final provider = MemoryConfigurationProvider(
///   initialData: {
///     'database:host': 'localhost',
///     'database:port': '5432',
///   },
/// );
/// provider.load();
/// ```
final class MemoryConfigurationProvider extends ConfigurationProvider {
  /// Creates a provider seeded with [initialData].
  MemoryConfigurationProvider({Map<String, String?>? initialData})
      : _initialData = initialData ?? const {};

  final Map<String, String?> _initialData;

  @override
  void load() {
    data.clear();
    for (final entry in _initialData.entries) {
      data[KeyNormalizer.normalize(entry.key)] = entry.value;
    }
  }

  @override
  ChangeToken getReloadToken() => const NeverChangeToken();
}

/// A [ConfigurationSource] that produces a [MemoryConfigurationProvider].
///
/// Register via [ConfigurationBuilder.addInMemory]:
/// ```dart
/// builder.addInMemory({'app:name': 'Orders'});
/// ```
final class MemoryConfigurationSource implements ConfigurationSource {
  /// Creates a source seeded with [initialData].
  const MemoryConfigurationSource({Map<String, String?>? initialData})
      : initialData = initialData ?? const {};

  /// The initial key-value pairs.
  final Map<String, String?> initialData;

  @override
  ConfigurationProvider build() =>
      MemoryConfigurationProvider(initialData: initialData);
}
