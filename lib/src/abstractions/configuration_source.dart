/// The [ConfigurationSource] interface.
library;

import 'configuration_provider.dart';

/// A factory that produces a [ConfigurationProvider].
///
/// Sources are registered with a [ConfigurationBuilder] and are responsible
/// for creating the appropriate [ConfigurationProvider] when [build] is
/// called.  All built-in providers expose a corresponding source class
/// (e.g. `MemoryConfigurationSource`, `JsonFileConfigurationSource`).
///
/// ### Custom source example
/// ```dart
/// class VaultConfigurationSource implements ConfigurationSource {
///   const VaultConfigurationSource({required this.vaultUrl});
///
///   final String vaultUrl;
///
///   @override
///   ConfigurationProvider build() =>
///       VaultConfigurationProvider(vaultUrl: vaultUrl);
/// }
/// ```
abstract interface class ConfigurationSource {
  /// Creates the [ConfigurationProvider] managed by this source.
  ConfigurationProvider build();
}
