/// Re-exports [ConfigurationSection] from the combined abstractions file.
///
/// [ConfigurationSection] and [Configuration] are defined together in
/// `configuration.dart` because each interface references the other.
/// This file exists so callers can import `configuration_section.dart`
/// directly by the conventional filename.
library;

export 'configuration.dart' show ConfigurationSection;
