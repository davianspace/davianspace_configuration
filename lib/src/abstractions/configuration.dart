/// Abstract interfaces that define the configuration surface area.
///
/// [Configuration] is the root capability; [ConfigurationSection] is a typed
/// view into a named subtree of that configuration.  Both interfaces are
/// defined here because [Configuration.getSection] returns [ConfigurationSection]
/// and [ConfigurationSection] extends [Configuration]; splitting them into
/// separate files would create a circular import.
library;

/// The top-level configuration API.
///
/// Provides key-value access, hierarchical section traversal, and child
/// enumeration over a merged view of one or more configuration providers.
///
/// Keys are colon-separated paths; lookup is case-insensitive:
/// - `"database:host"` accesses the `host` field inside a `database` block.
/// - `"logging:level:default"` accesses a three-level deep value.
///
/// ```dart
/// final config = ConfigurationBuilder()
///     .addInMemory({'database:host': 'localhost'})
///     .build();
///
/// final host = config['database:host'];              // 'localhost'
/// final section = config.getSection('database');
/// final sameHost = section['host'];                  // 'localhost'
/// ```
abstract interface class Configuration {
  /// Returns the raw string value stored at [key], or `null` when absent.
  ///
  /// [key] is a colon-separated path and is treated case-insensitively.
  String? operator [](String key);

  /// Writes [value] at [key].
  ///
  /// Setting a value on a [ConfigurationRoot] propagates the write to the
  /// last provider that contains the key, or to the first provider when no
  /// provider owns it yet.
  void operator []=(String key, String? value);

  /// Returns a [ConfigurationSection] rooted at [key].
  ///
  /// Always returns a non-null section even when no data exists at [key];
  /// in that case the section simply has no children and a `null` value.
  ConfigurationSection getSection(String key);

  /// Returns all direct child sections of this configuration node.
  Iterable<ConfigurationSection> getChildren();

  /// Returns the value at [key], throwing [StateError] when absent or `null`.
  ///
  /// Prefer this over `[key]!` because the exception message includes the
  /// missing key path.
  String getRequired(String key);
}

/// A named subtree within a [Configuration] hierarchy.
///
/// Every call to [Configuration.getSection] returns a [ConfigurationSection]
/// whose key-value operations are scoped to the path prefix of that section:
///
/// ```dart
/// final dbSection = config.getSection('database');
/// final host = dbSection['host'];   // equivalent to config['database:host']
/// ```
///
/// A section may itself have a scalar [value] (when the configuration source
/// sets `"database"` directly) *and* child sections
/// (`"database:host"`, etc.) simultaneously.
abstract interface class ConfigurationSection implements Configuration {
  /// The last path segment — this section's own name.
  ///
  /// For a section at path `"logging:level"` this is `"level"`.
  String get key;

  /// The full colon-separated path from the root to this section.
  ///
  /// For the section created by `config.getSection("logging")` this is
  /// `"logging"`.
  String get path;

  /// The scalar value stored directly at this section's path, or `null`
  /// when this node is a container with no direct value.
  String? get value;

  /// Sets the scalar value at this section's path.
  set value(String? val);
}
