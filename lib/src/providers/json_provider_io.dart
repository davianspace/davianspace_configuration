// dart:io implementation for JSON file loading and watching.
import 'dart:io' show File, FileSystemException;

/// Reads [path] and returns its contents as a string.
///
/// When [optional] is `true` a missing file returns `null` rather than
/// throwing.  All other I/O errors are re-thrown.
String? readFileSafe({required String path, required bool optional}) {
  final file = File(path);
  if (!file.existsSync()) {
    if (optional) return null;
    throw FileSystemException(
      'Required configuration file not found.',
      path,
    );
  }
  return file.readAsStringSync();
}

/// Subscribes to modification events on [path] and calls [onChanged] each
/// time the file is written.  No-op when file watching fails gracefully.
void watchFile({
  required String path,
  required void Function() onChanged,
}) {
  try {
    File(path).watch().listen((event) {
      if (event.path == path) onChanged();
    });
  } catch (_) {
    // Silently ignore watch errors (e.g. on unsupported file systems).
  }
}
