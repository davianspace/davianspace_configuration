// Web / WASM stub for JSON file loading.
// JsonFileConfigurationProvider should not be used on web targets.

/// Always throws [UnsupportedError] on web / WASM platforms.
String? readFileSafe({required String path, required bool optional}) {
  throw UnsupportedError(
    'JsonFileConfigurationProvider is not supported on web / WASM. '
    'Use JsonStringConfigurationProvider or addJsonString() instead.',
  );
}

/// No-op on web / WASM platforms.
void watchFile({
  required String path,
  required void Function() onChanged,
}) {
  // File watching is not available on web.
}
