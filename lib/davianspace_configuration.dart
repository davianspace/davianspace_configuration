/// A flexible, hierarchical configuration system for Dart and Flutter.
///
/// Equivalent in capability to Microsoft.Extensions.Configuration, adapted
/// idiomatically for Dart.
///
/// ## Quick start
///
/// ```dart
/// import 'package:davianspace_configuration/davianspace_configuration.dart';
///
/// void main() {
///   final config = ConfigurationBuilder()
///       .addInMemory({'app:name': 'Orders', 'database:host': 'localhost'})
///       .addEnvironmentVariables(prefix: 'APP_')
///       .build();
///
///   print(config['app:name']);           // Orders
///   print(config['database:host']);      // localhost (or env override)
///
///   final db = config.getSection('database');
///   print(db['host']);                   // localhost
/// }
/// ```
///
/// For mutable runtime configuration use [ConfigurationManager] instead of
/// [ConfigurationBuilder].
library;

// Abstractions
export 'src/abstractions/configuration.dart';
export 'src/abstractions/configuration_provider.dart';
export 'src/abstractions/configuration_section.dart';
export 'src/abstractions/configuration_source.dart';

// Core
export 'src/core/configuration_builder.dart';
export 'src/core/configuration_manager.dart';
export 'src/core/configuration_path.dart';
export 'src/core/configuration_root.dart';

// Providers
export 'src/providers/environment_provider.dart';
export 'src/providers/json_provider.dart';
export 'src/providers/map_provider.dart';
export 'src/providers/memory_provider.dart';

// Reload
export 'src/reload/change_notifier.dart';
export 'src/reload/change_token.dart';
export 'src/reload/reload_token.dart';

// Utils
export 'src/utils/key_normalizer.dart';
