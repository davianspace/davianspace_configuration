/// Normalizes configuration keys for consistent, case-insensitive lookup.
///
/// All keys are stored and compared in lowercase form, exactly as
/// Microsoft.Extensions.Configuration normalizes keys under the hood.
/// Call [normalize] on every key before inserting into or querying a
/// provider's internal data map.
library;

/// Utilities for normalizing configuration keys.
final class KeyNormalizer {
  const KeyNormalizer._();

  /// Returns [key] converted to lowercase.
  ///
  /// All path segments separated by [configurationPathSeparator] are
  /// individually normalized, so `"Database:Host"` and `"database:host"`
  /// are treated as the same key.
  static String normalize(String key) => key.toLowerCase();

  /// Returns `true` when [a] and [b] refer to the same configuration key
  /// after normalization.
  static bool equals(String a, String b) => a.toLowerCase() == b.toLowerCase();
}

/// The separator character used between path segments in a configuration key.
const String configurationPathSeparator = ':';
