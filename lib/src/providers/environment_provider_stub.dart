// Web / WASM stub — Platform.environment is not available in browsers.
// Returns an empty map so the environment provider loads nothing silently.

/// Returns an empty environment map on web / WASM platforms.
Map<String, String> getEnvironment() => const {};
