/// Helpers for constructing and decomposing colon-separated configuration paths.
library;

import '../utils/key_normalizer.dart';

/// Provides static utilities for working with hierarchical configuration keys.
///
/// Configuration keys use `:` as a path separator, so a setting stored under
/// `{"database": {"host": "localhost"}}` is accessed as `"database:host"`.
/// All methods normalize key segments to lowercase before combining them.
///
/// ```dart
/// ConfigurationPath.combine('database', 'host');       // "database:host"
/// ConfigurationPath.getSectionKey('database:host');    // "host"
/// ConfigurationPath.getParentPath('database:host');    // "database"
/// ```
final class ConfigurationPath {
  const ConfigurationPath._();

  /// The colon character used as the path separator.
  static const String separator = configurationPathSeparator;

  /// Combines [path1] and [path2] into a single colon-separated key.
  ///
  /// Either argument may be empty or null; empty segments are skipped.
  static String combine(String path1, String path2) {
    if (path1.isEmpty) return path2;
    if (path2.isEmpty) return path1;
    return '${path1.toLowerCase()}$separator${path2.toLowerCase()}';
  }

  /// Combines a list of path segments into a single colon-separated key.
  ///
  /// Empty segments are skipped.
  static String combineAll(List<String> paths) {
    final nonEmpty = paths.where((p) => p.isNotEmpty);
    return nonEmpty.map((p) => p.toLowerCase()).join(separator);
  }

  /// Returns the last segment of [path] — the section's own key name.
  ///
  /// For `"database:host"` returns `"host"`.
  /// For a top-level key `"host"` returns `"host"`.
  static String getSectionKey(String path) {
    if (path.isEmpty) return path;
    final lastSep = path.lastIndexOf(separator);
    return lastSep < 0
        ? path.toLowerCase()
        : path.substring(lastSep + 1).toLowerCase();
  }

  /// Returns the parent path of [path], or an empty string if [path] is
  /// already a top-level key.
  ///
  /// For `"database:host"` returns `"database"`.
  /// For `"host"` returns `""`.
  static String getParentPath(String path) {
    if (path.isEmpty) return '';
    final lastSep = path.lastIndexOf(separator);
    return lastSep < 0 ? '' : path.substring(0, lastSep).toLowerCase();
  }

  /// Splits [path] into its individual segments.
  static List<String> getSegments(String path) {
    if (path.isEmpty) return const [];
    return path.toLowerCase().split(separator);
  }
}
