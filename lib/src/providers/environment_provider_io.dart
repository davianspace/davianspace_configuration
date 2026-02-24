// dart:io implementation — native platforms only.
import 'dart:io' show Platform;

/// Returns the current process environment variables.
Map<String, String> getEnvironment() => Platform.environment;
