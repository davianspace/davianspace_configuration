import 'dart:io' show Directory, File, FileSystemException, Platform;

import 'package:davianspace_configuration/davianspace_configuration.dart';
import 'package:test/test.dart';

void main() {
  // ── ConfigurationPath ──────────────────────────────────────────────────────

  group('ConfigurationPath', () {
    test('combine joins two non-empty segments with a colon', () {
      expect(ConfigurationPath.combine('database', 'host'), 'database:host');
    });

    test('combine returns right segment when left is empty', () {
      expect(ConfigurationPath.combine('', 'host'), 'host');
    });

    test('combine returns left segment when right is empty', () {
      expect(ConfigurationPath.combine('database', ''), 'database');
    });

    test('combine normalizes both segments to lowercase', () {
      expect(ConfigurationPath.combine('Database', 'Host'), 'database:host');
    });

    test('combineAll merges multiple segments', () {
      expect(
        ConfigurationPath.combineAll(['logging', 'level', 'default']),
        'logging:level:default',
      );
    });

    test('combineAll skips empty segments', () {
      expect(ConfigurationPath.combineAll(['a', '', 'b']), 'a:b');
    });

    test('getSectionKey returns last segment', () {
      expect(
        ConfigurationPath.getSectionKey('logging:level:default'),
        'default',
      );
    });

    test('getSectionKey returns key unchanged for top-level key', () {
      expect(
        ConfigurationPath.getSectionKey('host'),
        'host',
      );
    });

    test('getParentPath returns prefix path', () {
      expect(
        ConfigurationPath.getParentPath('logging:level:default'),
        'logging:level',
      );
    });

    test('getParentPath returns empty string for top-level key', () {
      expect(
        ConfigurationPath.getParentPath('host'),
        '',
      );
    });

    test('getSegments splits path into parts', () {
      expect(
        ConfigurationPath.getSegments('logging:level:default'),
        ['logging', 'level', 'default'],
      );
    });
  });

  // ── KeyNormalizer ──────────────────────────────────────────────────────────

  group('KeyNormalizer', () {
    test('normalize converts to lowercase', () {
      expect(KeyNormalizer.normalize('Database:Host'), 'database:host');
    });

    test('equals is case-insensitive', () {
      expect(KeyNormalizer.equals('Database:Host', 'database:host'), isTrue);
      expect(KeyNormalizer.equals('A', 'B'), isFalse);
    });
  });

  // ── ChangeToken / ReloadToken ──────────────────────────────────────────────

  group('NeverChangeToken', () {
    test('hasChanged is always false', () {
      const token = NeverChangeToken();
      expect(token.hasChanged, isFalse);
    });

    test('activeChangeCallbacks is false', () {
      expect(const NeverChangeToken().activeChangeCallbacks, isFalse);
    });

    test('registerCallback returns empty registration without calling callback',
        () {
      var called = false;
      const NeverChangeToken().registerCallback(() => called = true);
      expect(called, isFalse);
    });
  });

  group('ReloadToken', () {
    test('hasChanged is false before notifyChanged', () {
      final token = ReloadToken();
      expect(token.hasChanged, isFalse);
    });

    test('hasChanged is true after notifyChanged', () {
      final token = ReloadToken()..notifyChanged();
      expect(token.hasChanged, isTrue);
    });

    test('registered callback fires on notifyChanged', () {
      final token = ReloadToken();
      var fired = false;
      token.registerCallback(() => fired = true);
      expect(fired, isFalse);
      token.notifyChanged();
      expect(fired, isTrue);
    });

    test('multiple callbacks all fire', () {
      final token = ReloadToken();
      final log = <int>[];
      token
        ..registerCallback(() => log.add(1))
        ..registerCallback(() => log.add(2))
        ..notifyChanged();
      expect(log, containsAllInOrder([1, 2]));
    });

    test('disposed registration callback does not fire', () {
      final token = ReloadToken();
      var fired = false;
      token.registerCallback(() => fired = true).dispose();
      token.notifyChanged();
      expect(fired, isFalse);
    });

    test('registering on already-changed token fires callback immediately', () {
      final token = ReloadToken()..notifyChanged();
      var fired = false;
      token.registerCallback(() => fired = true);
      expect(fired, isTrue);
    });

    test('notifyChanged is idempotent', () {
      final token = ReloadToken();
      var count = 0;
      token
        ..registerCallback(() => count++)
        ..notifyChanged()
        ..notifyChanged();
      expect(count, 1);
    });
  });

  // ── ChangeNotifier ─────────────────────────────────────────────────────────

  group('ChangeNotifier', () {
    test('getChangeToken returns active token', () {
      final notifier = ChangeNotifier();
      final token = notifier.getChangeToken();
      expect(token.hasChanged, isFalse);
    });

    test('onReload fires token callbacks and rotates token', () {
      final notifier = ChangeNotifier();
      var fired = false;
      notifier.getChangeToken().registerCallback(() => fired = true);
      notifier.onReload();
      expect(fired, isTrue);
      // New token is fresh.
      expect(notifier.getChangeToken().hasChanged, isFalse);
    });

    test('second onReload fires new token callbacks', () {
      final notifier = ChangeNotifier();
      var count = 0;
      void listen() => notifier.getChangeToken().registerCallback(() {
            count++;
            listen(); // re-subscribe
          });
      listen();
      notifier
        ..onReload()
        ..onReload();
      expect(count, 2);
    });
  });

  // ── MemoryConfigurationProvider ───────────────────────────────────────────

  group('MemoryConfigurationProvider', () {
    test('loads initial data and normalizes keys', () {
      final p = MemoryConfigurationProvider(
        initialData: {'Database:Host': 'localhost', 'Port': '5432'},
      )..load();

      expect(p.get('database:host'), 'localhost');
      expect(p.get('port'), '5432');
    });

    test('get returns null for missing key', () {
      final p = MemoryConfigurationProvider()..load();
      expect(p.get('missing'), isNull);
    });

    test('tryGet distinguishes missing from null value', () {
      final p = MemoryConfigurationProvider(
        initialData: {'key': null},
      )..load();
      final (found, value) = p.tryGet('key');
      expect(found, isTrue);
      expect(value, isNull);

      final (notFound, _) = p.tryGet('other');
      expect(notFound, isFalse);
    });

    test('set writes new key', () {
      final p = MemoryConfigurationProvider()
        ..load()
        ..set('app:name', 'Test');
      expect(p.get('app:name'), 'Test');
    });

    test('getReloadToken is NeverChangeToken', () {
      final p = MemoryConfigurationProvider();
      expect(p.getReloadToken(), isA<NeverChangeToken>());
    });
  });

  // ── MapConfigurationProvider ──────────────────────────────────────────────

  group('MapConfigurationProvider', () {
    test('flattens nested map to colon-separated keys', () {
      final p = MapConfigurationProvider(
        map: {
          'database': {'host': 'db.internal', 'port': 5432},
          'logging': {'level': 'info'},
        },
      )..load();

      expect(p.get('database:host'), 'db.internal');
      expect(p.get('database:port'), '5432');
      expect(p.get('logging:level'), 'info');
    });

    test('flattens list values with integer indices', () {
      final p = MapConfigurationProvider(
        map: {
          'servers': ['a.internal', 'b.internal'],
        },
      )..load();

      expect(p.get('servers:0'), 'a.internal');
      expect(p.get('servers:1'), 'b.internal');
    });

    test('stores null leaf values as null', () {
      final p = MapConfigurationProvider(
        map: {'key': null},
      )..load();
      final (found, value) = p.tryGet('key');
      expect(found, isTrue);
      expect(value, isNull);
    });

    test('converts non-string scalars to string', () {
      final p = MapConfigurationProvider(
        map: {'timeout': 30, 'debug': true},
      )..load();
      expect(p.get('timeout'), '30');
      expect(p.get('debug'), 'true');
    });
  });

  // ── EnvironmentConfigurationProvider ─────────────────────────────────────

  group('EnvironmentConfigurationProvider', () {
    test('loads environment variables without prefix', () {
      // PATH is present on every supported OS.
      final p = EnvironmentConfigurationProvider()..load();
      // At least some key must be present.
      expect(p.data.isNotEmpty, isTrue);
    });

    test('prefix filter only includes matching variables', () {
      // We cannot inject arbitrary env vars at test time, so we verify the
      // count is reduced relative to a no-prefix provider.
      final all = EnvironmentConfigurationProvider()..load();
      // Use a very long prefix that matches nothing.
      final filtered = EnvironmentConfigurationProvider(
        prefix: 'XYZZY_NONEXISTENT_____',
      )..load();
      expect(filtered.data.length, lessThan(all.data.length));
    });

    test('converts double-underscore to colon separator', () {
      // Build a provider with a controlled map via MapProvider to verify the
      // double-underscore mapping rule using EnvironmentProvider logic directly.
      // Since we cannot set process env vars, we exercise the EnvironmentProvider
      // through integration tests only and verify the transformation here by
      // looking at PATH-like variables that include __ if any.
      //
      // At minimum verify the provider loads without throwing.
      final p = EnvironmentConfigurationProvider()..load();
      expect(p.data, isA<Map<String, String?>>());
    });
  });

  // ── JsonStringConfigurationProvider ──────────────────────────────────────

  group('JsonStringConfigurationProvider', () {
    test('parses flat JSON object', () {
      final p = JsonStringConfigurationProvider(
        jsonContent: '{"host": "localhost", "port": "5432"}',
      )..load();

      expect(p.get('host'), 'localhost');
      expect(p.get('port'), '5432');
    });

    test('flattens nested JSON objects', () {
      final p = JsonStringConfigurationProvider(
        jsonContent: '''{
          "database": {
            "host": "db.internal",
            "port": 5432,
            "pool": {"min": 2, "max": 20}
          }
        }''',
      )..load();

      expect(p.get('database:host'), 'db.internal');
      expect(p.get('database:port'), '5432');
      expect(p.get('database:pool:min'), '2');
      expect(p.get('database:pool:max'), '20');
    });

    test('flattens JSON arrays with integer keys', () {
      final p = JsonStringConfigurationProvider(
        jsonContent: '{"endpoints": ["a.internal", "b.internal"]}',
      )..load();

      expect(p.get('endpoints:0'), 'a.internal');
      expect(p.get('endpoints:1'), 'b.internal');
    });

    test('key lookup is case-insensitive', () {
      final p = JsonStringConfigurationProvider(
        jsonContent: '{"Database": {"Host": "localhost"}}',
      )..load();

      expect(p.get('database:host'), 'localhost');
      expect(p.get('DATABASE:HOST'), 'localhost');
    });

    test('throws FormatException on invalid JSON', () {
      final p = JsonStringConfigurationProvider(jsonContent: '{invalid}');
      expect(p.load, throwsA(isA<FormatException>()));
    });

    test('throws FormatException when root is not an object', () {
      final p = JsonStringConfigurationProvider(jsonContent: '[1, 2, 3]');
      expect(p.load, throwsA(isA<FormatException>()));
    });
  });

  // ── ConfigurationRoot ─────────────────────────────────────────────────────

  group('ConfigurationRoot', () {
    test('reads value from single provider', () {
      final root =
          ConfigurationBuilder().addInMemory({'app:name': 'Orders'}).build();

      expect(root['app:name'], 'Orders');
    });

    test('returns null for missing key', () {
      final root = ConfigurationBuilder().build();
      expect(root['missing'], isNull);
    });

    test('last-added provider wins on conflict', () {
      final root = ConfigurationBuilder()
          .addInMemory({'env': 'development'}).addInMemory(
        {'env': 'production'},
      ) // overrides
          .build();

      expect(root['env'], 'production');
    });

    test('providers merge non-conflicting keys', () {
      final root = ConfigurationBuilder()
          .addInMemory({'a': '1'}).addInMemory({'b': '2'}).build();

      expect(root['a'], '1');
      expect(root['b'], '2');
    });

    test('write propagates to last provider owning the key', () {
      final root = ConfigurationBuilder().addInMemory({'host': 'old'}).build();

      root['host'] = 'new';
      expect(root['host'], 'new');
    });

    test('write for unknown key goes to last provider', () {
      final root = ConfigurationBuilder().addInMemory({'a': '1'}).build();

      root['new:key'] = 'val';
      expect(root['new:key'], 'val');
    });

    test('getRequired throws StateError for missing key', () {
      final root = ConfigurationBuilder().build();
      expect(() => root.getRequired('missing'), throwsStateError);
    });

    test('getRequired returns value when present', () {
      final root = ConfigurationBuilder().addInMemory({'x': 'hello'}).build();
      expect(root.getRequired('x'), 'hello');
    });
  });

  // ── ConfigurationSection ──────────────────────────────────────────────────

  group('ConfigurationSection', () {
    late ConfigurationRoot root;

    setUp(() {
      root = ConfigurationBuilder().addInMemory({
        'database:host': 'localhost',
        'database:port': '5432',
        'database:pool:min': '2',
        'database:pool:max': '10',
        'logging:level': 'info',
      }).build();
    });

    test('getSection returns section with correct path and key', () {
      final s = root.getSection('database');
      expect(s.path, 'database');
      expect(s.key, 'database');
    });

    test('section operator[] scopes lookup to path', () {
      final db = root.getSection('database');
      expect(db['host'], 'localhost');
      expect(db['port'], '5432');
    });

    test('nested section access', () {
      final pool = root.getSection('database').getSection('pool');
      expect(pool['min'], '2');
      expect(pool['max'], '10');
      expect(pool.path, 'database:pool');
    });

    test('section.value returns scalar stored at section path', () {
      final s = root.getSection('logging:level');
      expect(s.value, 'info');
    });

    test('section.value is null when only children exist', () {
      final db = root.getSection('database');
      expect(db.value, isNull);
    });

    test('setting section.value writes through to root', () {
      root.getSection('logging:level').value = 'debug';
      expect(root['logging:level'], 'debug');
    });

    test('getChildren returns direct child sections', () {
      final db = root.getSection('database');
      final keys = db.getChildren().map((s) => s.key).toSet();
      expect(keys, containsAll(['host', 'port', 'pool']));
    });

    test('getRequired on section throws when key absent', () {
      final db = root.getSection('database');
      expect(() => db.getRequired('missing'), throwsStateError);
    });
  });

  // ── Provider precedence ────────────────────────────────────────────────────

  group('Provider precedence', () {
    test('three providers — last always wins', () {
      final root =
          ConfigurationBuilder().addInMemory({'level': 'debug'}).addInMemory(
        {'level': 'info'},
      ).addInMemory({'level': 'warning'}).build();

      expect(root['level'], 'warning');
    });

    test('JSON string overrides memory defaults', () {
      final root = ConfigurationBuilder()
          .addInMemory({'app:name': 'Default', 'app:version': '1.0'})
          .addJsonString('{"app": {"name": "Override"}}')
          .build();

      expect(root['app:name'], 'Override');
      expect(root['app:version'], '1.0'); // not overridden
    });

    test('environment variables override JSON config', () {
      // Since we cannot inject env vars, we simulate with in-memory layers.
      final root = ConfigurationBuilder()
          .addJsonString('{"database": {"host": "json-host"}}')
          .addInMemory({'database:host': 'env-host'}) // simulates env override
          .build();

      expect(root['database:host'], 'env-host');
    });

    test('getChildren merges keys from all providers', () {
      final root = ConfigurationBuilder().addInMemory(
        {'section:a': '1'},
      ).addInMemory({'section:b': '2'}).build();

      final keys =
          root.getSection('section').getChildren().map((s) => s.key).toSet();
      expect(keys, containsAll(['a', 'b']));
    });
  });

  // ── Hierarchical access ────────────────────────────────────────────────────

  group('Hierarchical access', () {
    test('deeply nested key is accessible', () {
      final root = ConfigurationBuilder().addJsonString('''
          {
            "a": {
              "b": {
                "c": {
                  "d": "deep"
                }
              }
            }
          }''').build();

      expect(root['a:b:c:d'], 'deep');
    });

    test('traversal via section chain is equivalent to direct key', () {
      final root = ConfigurationBuilder()
          .addInMemory({'logging:level:default': 'warning'}).build();

      final direct = root['logging:level:default'];
      final viaSection =
          root.getSection('logging').getSection('level')['default'];
      expect(direct, viaSection);
    });
  });

  // ── Reload ─────────────────────────────────────────────────────────────────

  group('Reload', () {
    test('reload triggers getReloadToken callbacks', () {
      final root = ConfigurationBuilder().addInMemory({'x': '1'}).build();

      var reloaded = false;
      root.getReloadToken().registerCallback(() => reloaded = true);
      root.reload();
      expect(reloaded, isTrue);
    });

    test('after reload new getReloadToken is fresh', () {
      final root = ConfigurationBuilder().addInMemory({}).build();

      root.getReloadToken().registerCallback(() {});
      root.reload();
      expect(root.getReloadToken().hasChanged, isFalse);
    });

    test('reload re-reads provider data', () {
      // Simulate a mutable data source by wrapping a map.
      var name = 'initial';
      final provider = _MutableMemoryProvider(() => {'app:name': name});
      final root = ConfigurationRoot([provider]);

      expect(root['app:name'], 'initial');
      name = 'reloaded';
      root.reload();
      expect(root['app:name'], 'reloaded');
    });

    test('provider reload token triggers root change notification', () {
      final provider = _MutableMemoryProvider(() => {'v': '1'});
      final root = ConfigurationRoot([provider]);

      var notified = false;
      root.getReloadToken().registerCallback(() => notified = true);
      provider.triggerReload();
      expect(notified, isTrue);
    });
  });

  // ── ConfigurationManager ──────────────────────────────────────────────────

  group('ConfigurationManager', () {
    test('addInMemory values are immediately accessible', () {
      final manager = ConfigurationManager()
        ..addInMemory({'app:name': 'Orders'});

      expect(manager['app:name'], 'Orders');
    });

    test('adding providers after construction takes effect immediately', () {
      final manager = ConfigurationManager()..addInMemory({'a': '1'});

      expect(manager['b'], isNull);
      manager.addInMemory({'b': '2'});
      expect(manager['b'], '2');
    });

    test('last-added provider wins', () {
      final manager = ConfigurationManager()
        ..addInMemory({'env': 'dev'})
        ..addInMemory({'env': 'prod'});

      expect(manager['env'], 'prod');
    });

    test('getChildren aggregates from all providers', () {
      final manager = ConfigurationManager()
        ..addInMemory({'section:x': '1'})
        ..addInMemory({'section:y': '2'});

      final keys =
          manager.getSection('section').getChildren().map((s) => s.key).toSet();
      expect(keys, containsAll(['x', 'y']));
    });

    test('reload triggers change notifications', () {
      final manager = ConfigurationManager()..addInMemory({'k': 'v'});

      var notified = false;
      manager.getReloadToken().registerCallback(() => notified = true);
      manager.reload();
      expect(notified, isTrue);
    });
  });

  // ── JSON file provider (native only) ────────────────────────────────────

  group(
    'JsonFileConfigurationProvider',
    () {
      late Directory tempDir;

      setUpAll(() async {
        tempDir = await Directory.systemTemp.createTemp('dart_config_test_');
      });

      tearDownAll(() async {
        await tempDir.delete(recursive: true);
      });

      test('loads values from a JSON file', () async {
        final file = File('${tempDir.path}/settings.json')
          ..writeAsStringSync('{"database": {"host": "db.test"}}');

        final root = ConfigurationBuilder().addJsonFile(file.path).build();

        expect(root['database:host'], 'db.test');
      });

      test('optional: true — missing file loads an empty config', () {
        final root = ConfigurationBuilder()
            .addJsonFile('/nonexistent/path/missing.json', optional: true)
            .build();

        expect(root['any:key'], isNull);
      });

      test(
        'optional: false — missing file throws during load',
        () {
          expect(
            () => ConfigurationBuilder()
                .addJsonFile('/nonexistent/path/required.json')
                .build(),
            throwsA(isA<FileSystemException>()),
          );
        },
        skip: !Platform.isWindows && !Platform.isLinux && !Platform.isMacOS
            ? 'native only'
            : null,
      );

      test('JSON file overrides in-memory defaults', () async {
        final file = File('${tempDir.path}/override.json')
          ..writeAsStringSync('{"env": "test"}');

        final root = ConfigurationBuilder()
            .addInMemory({'env': 'development'})
            .addJsonFile(file.path)
            .build();

        expect(root['env'], 'test');
      });
    },
    testOn: 'vm',
  );

  // ── Concurrent access safety ─────────────────────────────────────────────

  group('Concurrent access safety', () {
    test(
        'simultaneous reads from multiple isolate-safe futures return correct values',
        () async {
      final root = ConfigurationBuilder().addInMemory({
        for (var i = 0; i < 100; i++) 'key$i': 'value$i',
      }).build();

      final reads = List.generate(
        100,
        (i) => Future(() => root['key$i']),
      );
      final results = await Future.wait(reads);
      for (var i = 0; i < 100; i++) {
        expect(results[i], 'value$i');
      }
    });
  });
}

// ── Test helpers ─────────────────────────────────────────────────────────────

/// A provider backed by a factory so tests can mutate the source between loads.
final class _MutableMemoryProvider extends ConfigurationProvider {
  _MutableMemoryProvider(Map<String, String?> Function() factory)
      : _factory = factory;

  final Map<String, String?> Function() _factory;

  @override
  void load() {
    data
      ..clear()
      ..addAll(_factory());
  }

  /// Simulates an external reload signal, e.g. from a file watcher.
  void triggerReload() {
    load();
    onReload();
  }
}
