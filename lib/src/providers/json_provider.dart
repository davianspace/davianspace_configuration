/// JSON configuration providers — string-based and file-based.
///
/// [JsonStringConfigurationProvider] works on all platforms.
/// [JsonFileConfigurationProvider] requires a native Dart / Flutter platform
/// (VM, AOT, Flutter mobile / desktop) and uses conditional imports to
/// compile safely on web targets.
library;

import 'dart:convert' show json;

import '../abstractions/configuration_provider.dart';
import '../abstractions/configuration_source.dart';
import '../core/configuration_path.dart';
import '../reload/change_token.dart';
import '../utils/key_normalizer.dart';

// Conditional import: full file I/O on native, stub on web.
import 'json_provider_io.dart'
    if (dart.library.html) 'json_provider_stub.dart'
    if (dart.library.js_interop) 'json_provider_stub.dart' as file_helper;

// ── JSON string provider ─────────────────────────────────────────────────────

/// A [ConfigurationProvider] that parses a JSON string.
///
/// The JSON is flattened into colon-separated keys, exactly as
/// [MapConfigurationProvider] flattens a `Map<String, dynamic>`.  The root
/// value must be a JSON object (`{}`); arrays at the root are not supported.
///
/// This provider works on all platforms (native, web, WASM).
///
/// ```dart
/// final provider = JsonStringConfigurationProvider(
///   jsonContent: '{"database": {"host": "localhost", "port": 5432}}',
/// );
/// provider.load();
/// print(provider.get('database:host')); // 'localhost'
/// ```
final class JsonStringConfigurationProvider extends ConfigurationProvider {
  /// Creates a provider from an in-memory [jsonContent] string.
  ///
  /// Parsing is deferred until [load] is called.
  JsonStringConfigurationProvider({required String jsonContent})
      : _jsonContent = jsonContent;

  final String _jsonContent;

  @override
  void load() {
    data.clear();
    final Object? decoded;
    try {
      decoded = json.decode(_jsonContent);
    } on FormatException catch (e) {
      throw FormatException(
        'Failed to parse JSON configuration content: ${e.message}',
        _jsonContent,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'JSON configuration content must be a JSON object ({...}), '
        'got ${decoded.runtimeType}.',
      );
    }
    _flatten(decoded, '');
  }

  @override
  ChangeToken getReloadToken() => const NeverChangeToken();

  void _flatten(Object? node, String prefix) {
    if (node is Map<String, dynamic>) {
      if (node.isEmpty && prefix.isNotEmpty) {
        // Preserve empty section markers.
        data[KeyNormalizer.normalize(prefix)] = null;
        return;
      }
      for (final entry in node.entries) {
        final childPath = ConfigurationPath.combine(prefix, entry.key);
        _flatten(entry.value, childPath);
      }
    } else if (node is List<dynamic>) {
      if (node.isEmpty && prefix.isNotEmpty) {
        data[KeyNormalizer.normalize(prefix)] = null;
        return;
      }
      for (var i = 0; i < node.length; i++) {
        final childPath = ConfigurationPath.combine(prefix, i.toString());
        _flatten(node[i], childPath);
      }
    } else {
      data[KeyNormalizer.normalize(prefix)] = node?.toString();
    }
  }
}

/// A [ConfigurationSource] that produces a [JsonStringConfigurationProvider].
///
/// Register via [ConfigurationBuilder.addJsonString]:
/// ```dart
/// builder.addJsonString('{"app": {"name": "Orders"}}');
/// ```
final class JsonStringConfigurationSource implements ConfigurationSource {
  /// Creates a source from an in-memory [jsonContent] string.
  const JsonStringConfigurationSource({required String jsonContent})
      : _jsonContent = jsonContent;

  final String _jsonContent;

  @override
  ConfigurationProvider build() =>
      JsonStringConfigurationProvider(jsonContent: _jsonContent);
}

// ── JSON file provider ───────────────────────────────────────────────────────

/// A [ConfigurationProvider] that reads configuration from a JSON file.
///
/// When [optional] is `true` a missing file is silently ignored rather than
/// throwing a `FileSystemException`.  When [reloadOnChange] is `true` the
/// provider subscribes to file-system events and reloads automatically.
///
/// > **Platform note**: requires a native Dart / Flutter platform.
/// > On web targets, calling [load] throws an [UnsupportedError].
/// > Use [JsonStringConfigurationProvider] for cross-platform JSON loading.
final class JsonFileConfigurationProvider
    extends JsonStringConfigurationProvider {
  /// Creates a provider that reads from [filePath].
  JsonFileConfigurationProvider({
    required String filePath,
    bool optional = false,
    bool reloadOnChange = false,
  })  : _filePath = filePath,
        _optional = optional,
        _reloadOnChange = reloadOnChange,
        super(jsonContent: '');

  final String _filePath;
  final bool _optional;
  final bool _reloadOnChange;

  @override
  void load() {
    final content = file_helper.readFileSafe(
      path: _filePath,
      optional: _optional,
    );
    if (content == null) {
      data.clear();
      return;
    }
    // Temporarily override the private content by reparsing...
    // Delegate to the parent flatten logic via a temporary provider.
    final tmp = JsonStringConfigurationProvider(jsonContent: content)..load();
    data
      ..clear()
      ..addAll(tmp.data);

    if (_reloadOnChange) {
      file_helper.watchFile(
        path: _filePath,
        onChanged: () {
          load();
          onReload();
        },
      );
    }
  }
}

/// A [ConfigurationSource] that produces a [JsonFileConfigurationProvider].
///
/// Register via [ConfigurationBuilder.addJsonFile]:
/// ```dart
/// builder
///     .addJsonFile('appsettings.json')
///     .addJsonFile('appsettings.production.json', optional: true)
///     .addJsonFile('appsettings.local.json', optional: true, reloadOnChange: true);
/// ```
final class JsonFileConfigurationSource implements ConfigurationSource {
  /// Creates a source for [filePath].
  const JsonFileConfigurationSource({
    required String filePath,
    bool optional = false,
    bool reloadOnChange = false,
  })  : _filePath = filePath,
        _optional = optional,
        _reloadOnChange = reloadOnChange;

  final String _filePath;
  final bool _optional;
  final bool _reloadOnChange;

  @override
  ConfigurationProvider build() => JsonFileConfigurationProvider(
        filePath: _filePath,
        optional: _optional,
        reloadOnChange: _reloadOnChange,
      );
}
