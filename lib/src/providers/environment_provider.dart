/// Configuration provider that reads from process environment variables.
///
/// On non-native platforms (Dart web / WASM) `Platform.environment` is
/// unavailable.  The provider silently loads an empty map in that case,
/// so including [EnvironmentConfigurationSource] in a cross-platform
/// build is safe — environment overrides simply have no effect on web.
library;

import '../abstractions/configuration_provider.dart';
import '../abstractions/configuration_source.dart';
import '../reload/change_token.dart';
import '../utils/key_normalizer.dart';

// Conditional import: stub on web, dart:io on native.
import 'environment_provider_io.dart'
    if (dart.library.html) 'environment_provider_stub.dart'
    if (dart.library.js_interop) 'environment_provider_stub.dart' as env_helper;

/// A [ConfigurationProvider] that loads from system environment variables.
///
/// ### Prefix filtering
/// When [prefix] is non-empty, only variables whose names start with [prefix]
/// (case-insensitive) are included.  The prefix (and the trailing underscore
/// that typically follows it) is stripped before the key is stored.
///
/// ### Key mapping
/// Double underscores (`__`) in variable names are converted to colon
/// separators, allowing hierarchical settings to be expressed in flat
/// environment variables:
///
/// ```
/// APP__DATABASE__HOST=db.prod.internal
///   → with prefix 'APP_': database:host = 'db.prod.internal'
/// ```
///
/// ### Reload
/// Environment variables are process-wide and do not change after the
/// process starts, so [getReloadToken] returns a [NeverChangeToken].
final class EnvironmentConfigurationProvider extends ConfigurationProvider {
  /// Creates a provider with optional [prefix] filtering.
  EnvironmentConfigurationProvider({this.prefix = ''});

  /// The environment variable prefix to filter on, e.g. `'APP_'`.
  final String prefix;

  @override
  void load() {
    data.clear();
    final env = env_helper.getEnvironment();
    final normalizedPrefix = prefix.toLowerCase();

    for (final entry in env.entries) {
      final normalizedName = entry.key.toLowerCase();

      if (normalizedPrefix.isNotEmpty &&
          !normalizedName.startsWith(normalizedPrefix)) {
        continue;
      }

      // Strip prefix.
      var key = normalizedPrefix.isNotEmpty
          ? normalizedName.substring(normalizedPrefix.length)
          : normalizedName;

      // Remove a leading underscore left after prefix stripping
      // (e.g. APP_ → key starts with _ when env var is APP_X).
      if (key.startsWith('_')) key = key.substring(1);

      // Convert double underscores to colon separators.
      key = key.replaceAll('__', ':');

      if (key.isNotEmpty) {
        data[KeyNormalizer.normalize(key)] = entry.value;
      }
    }
  }

  @override
  ChangeToken getReloadToken() => const NeverChangeToken();
}

/// A [ConfigurationSource] that produces an [EnvironmentConfigurationProvider].
///
/// Register via [ConfigurationBuilder.addEnvironmentVariables]:
/// ```dart
/// // Include all environment variables:
/// builder.addEnvironmentVariables();
///
/// // Include only variables prefixed with 'APP_':
/// builder.addEnvironmentVariables(prefix: 'APP_');
/// ```
final class EnvironmentConfigurationSource implements ConfigurationSource {
  /// Creates a source with optional [prefix] filtering.
  const EnvironmentConfigurationSource({this.prefix = ''});

  /// The prefix to filter environment variables on.
  final String prefix;

  @override
  ConfigurationProvider build() =>
      EnvironmentConfigurationProvider(prefix: prefix);
}
