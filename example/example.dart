// Examples use print for observable output; this is intentional in example code.
// ignore_for_file: avoid_print

import 'dart:io' show File, Directory;

import 'package:davianspace_configuration/davianspace_configuration.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

/// Strongly-typed wrapper around the database configuration section.
///
/// All values are extracted from the generic configuration and exposed as
/// typed fields.  Bind this in an ioc container or pass it directly to
/// repositories.
class DatabaseConfig {
  DatabaseConfig.fromConfiguration(Configuration config) {
    final s = config.getSection('database');
    host = s['host'] ?? 'localhost';
    port = int.parse(s['port'] ?? '5432');
    database = s.getRequired('name');
    maxPoolSize = int.parse(s['pool:maxSize'] ?? '10');
    enableSsl = (s['ssl'] ?? 'false').toLowerCase() == 'true';
  }

  late final String host;
  late final int port;
  late final String database;
  late final int maxPoolSize;
  late final bool enableSsl;

  String get connectionString =>
      '${enableSsl ? 'postgresql+ssl' : 'postgresql'}://$host:$port/$database'
      '?pool_max_size=$maxPoolSize';
}

/// Strongly-typed logging configuration.
class LoggingConfig {
  LoggingConfig.fromConfiguration(Configuration config) {
    final s = config.getSection('logging');
    defaultLevel = s['level:default'] ?? 'information';
    minimumLevel = s['level:minimum'] ?? 'debug';
  }

  late final String defaultLevel;
  late final String minimumLevel;
}

// ---------------------------------------------------------------------------
// Example 1 — Simple builder and direct key access
//
// ConfigurationBuilder composes multiple sources (last-added wins) and
// returns a ConfigurationRoot that provides O(1) key lookup.
// ---------------------------------------------------------------------------

void exampleBuilderAndDirectAccess() {
  print('── Example 1: Builder and direct key access ──────────────────────');

  final config = ConfigurationBuilder().addInMemory({
    'app:name': 'Orders',
    'app:version': '2.1.0',
    'database:host': 'localhost',
    'database:port': '5432',
    'database:name': 'orders',
    'database:ssl': 'false',
  }).build();

  // Direct, colon-separated path access — case-insensitive.
  print('  App name    : ${config['app:name']}');
  print('  App version : ${config['app:version']}');
  print('  DB host     : ${config['database:host']}');
  print('  DB port     : ${config['database:port']}');
}

// ---------------------------------------------------------------------------
// Example 2 — Section access and strongly-typed binding
//
// getSection() returns a ConfigurationSection scoped to a path prefix.
// All key lookups inside the section are relative to that prefix.
// ---------------------------------------------------------------------------

void exampleSectionAccess() {
  print('\n── Example 2: Section access and typed binding ───────────────────');

  final config = ConfigurationBuilder().addMap({
    'database': {
      'host': 'db.prod.internal',
      'port': 5432,
      'name': 'orders',
      'ssl': 'true',
      'pool': {'maxSize': 25},
    },
    'logging': {
      'level': {'default': 'information', 'minimum': 'warning'},
    },
  }).build();

  // Direct section traversal.
  final db = config.getSection('database');
  print('  DB host (via section) : ${db['host']}');
  print('  DB pool max (nested)  : ${db['pool:maxSize']}');
  print('  DB path               : ${db.path}');

  // Bind to typed objects — no reflection required.
  final dbConfig = DatabaseConfig.fromConfiguration(config);
  final logConfig = LoggingConfig.fromConfiguration(config);

  print('  Connection string : ${dbConfig.connectionString}');
  print('  Log level default : ${logConfig.defaultLevel}');
}

// ---------------------------------------------------------------------------
// Example 3 — Provider precedence and layered override
//
// Sources are evaluated in registration order.  The last-added source
// wins on conflicts so environment variables reliably override JSON files.
// ---------------------------------------------------------------------------

void exampleProviderPrecedence() {
  print('\n── Example 3: Provider precedence (last-added wins) ──────────────');

  // Simulates: base JSON → environment JSON → runtime overrides.
  final config = ConfigurationBuilder()
      // Tier 1 — base settings.
      .addInMemory({
    'app:name': 'Orders',
    'database:host': 'localhost',
    'logging:level': 'debug',
  })
      // Tier 2 — production JSON overrides (simulated with addJsonString).
      .addJsonString('''{
        "database": {
          "host": "db.prod.internal",
          "port": 5432
        }
      }''')
      // Tier 3 — operator or CI overrides (simulated with in-memory).
      .addInMemory({'logging:level': 'warning'}).build();

  print('  app:name      = ${config['app:name']}'); // from tier 1
  print('  database:host = ${config['database:host']}'); // from tier 2
  print('  database:port = ${config['database:port']}'); // from tier 2
  print('  logging:level = ${config['logging:level']}'); // from tier 3
}

// ---------------------------------------------------------------------------
// Example 4 — Environment variable provider
//
// Environment variables are loaded with optional prefix filtering.
// Double underscores (__) in variable names map to colon separators,
// enabling hierarchical config: APP__DATABASE__HOST → database:host.
// ---------------------------------------------------------------------------

void exampleEnvironmentVariables() {
  print('\n── Example 4: Environment variable provider ──────────────────────');

  // Load all environment variables with no prefix.
  final config = ConfigurationBuilder().addEnvironmentVariables().build();

  // PATH is available on all supported platforms.
  final path = config['path'];
  print('  PATH (from env) : ${path?.substring(0, 40)}...');

  // With a prefix — only variables starting with 'APP_' are included
  // and the prefix is stripped from keys.
  //
  // In a real deployment you would set:
  //   APP__DATABASE__HOST=db.prod.internal
  //   APP__DATABASE__PORT=5432
  //
  // Then:
  //   config['database:host']  →  'db.prod.internal'
  //   config['database:port']  →  '5432'
  final prefixed =
      ConfigurationBuilder().addEnvironmentVariables(prefix: 'APP_').build();

  print('  APP_ prefixed keys loaded: ${prefixed.getChildren().length}');
}

// ---------------------------------------------------------------------------
// Example 5 — JSON file provider with optional and layered files
//
// JSON files are flattened to colon-separated keys.  Mark environment-
// specific files as optional so the application starts cleanly when
// a local override file is absent.
// ---------------------------------------------------------------------------

void exampleJsonFiles() {
  print('\n── Example 5: JSON file provider ────────────────────────────────');

  final tempDir = Directory.systemTemp.createTempSync('davianspace_config_ex_');
  try {
    // Write simulated config files.
    File('${tempDir.path}/appsettings.json').writeAsStringSync('''{
          "app": { "name": "Orders", "version": "1.0" },
          "database": { "host": "localhost", "port": 5432 },
          "logging": { "level": { "default": "information" } }
        }''');

    File('${tempDir.path}/appsettings.production.json').writeAsStringSync('''{
          "database": { "host": "db.prod.internal" },
          "logging": { "level": { "default": "warning" } }
        }''');

    final config = ConfigurationBuilder()
        .addJsonFile('${tempDir.path}/appsettings.json')
        .addJsonFile(
          '${tempDir.path}/appsettings.production.json',
          optional: true,
        )
        // A per-developer local override file that typically does not exist in CI.
        .addJsonFile(
          '${tempDir.path}/appsettings.local.json',
          optional: true,
        )
        .build();

    print('  app:name      = ${config['app:name']}');
    print('  database:host = ${config['database:host']}'); // production file
    print(
      '  logging:level = ${config['logging:level:default']}',
    ); // production file
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// Example 6 — Runtime reload detection
//
// Obtain the reload token before the event, register a callback, then
// trigger a reload.  The callback fires synchronously.
// ---------------------------------------------------------------------------

void exampleReloadDetection() {
  print('\n── Example 6: Runtime reload detection ──────────────────────────');

  final currentVersion = '1.0.0';
  final config = ConfigurationBuilder().addMap(
    {
      'app': {'version': currentVersion},
    },
  ).build();

  print('  Version before reload : ${config['app:version']}');

  // Subscribe before triggering the reload so the callback is registered.
  config.getReloadToken().registerCallback(() {
    print('  [onChange] Configuration reloaded');
  });

  // Simulate an external signal (e.g. a file watcher, a remote config push).
  // In production, the provider's own reload mechanism triggers this.
  config.reload();

  // After reload, the new token is fresh.
  print('  Version after reload  : ${config['app:version']}');
  print('  New token changed?    : ${config.getReloadToken().hasChanged}');
}

// ---------------------------------------------------------------------------
// Example 7 — ConfigurationManager (mutable runtime configuration)
//
// ConfigurationManager is both a builder and a live configuration.
// Adding a provider takes effect immediately without rebuilding.
// ---------------------------------------------------------------------------

void exampleConfigurationManager() {
  print('\n── Example 7: ConfigurationManager (mutable runtime config) ─────');

  final manager = ConfigurationManager()
    ..addInMemory({'feature:darkMode': 'false', 'app:name': 'Orders'});

  print('  [Before] dark mode : ${manager['feature:darkMode']}');

  // Application code may add providers at runtime — e.g. after querying a
  // remote feature-flag service on startup.
  manager.addMap(
    {
      'feature': {'darkMode': 'true', 'betaSearch': 'true'},
    },
  );

  print('  [After]  dark mode   : ${manager['feature:darkMode']}');
  print('  [After]  beta search : ${manager['feature:betaSearch']}');
  print('  [Merged] app name    : ${manager['app:name']}');
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  exampleBuilderAndDirectAccess();
  exampleSectionAccess();
  exampleProviderPrecedence();
  exampleEnvironmentVariables();
  exampleJsonFiles();
  exampleReloadDetection();
  exampleConfigurationManager();
}
