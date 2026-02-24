/// A utility that maintains the currently-active [ReloadToken] and replaces
/// it atomically on each reload signal.
///
/// [ChangeNotifier] is used by [ConfigurationRoot] to aggregate reload events
/// from all registered providers and propagate them to root-level listeners.
library;

import 'change_token.dart';
import 'reload_token.dart';

/// Manages a rotating series of [ReloadToken]s.
///
/// [ConfigurationRoot] holds one [ChangeNotifier] instance.  When any
/// provider reloads, it calls [onReload] which:
///   1. Creates a new [ReloadToken] to serve future `getChangeToken()` calls.
///   2. Fires the **previous** token, invoking all registered listeners.
///
/// ```dart
/// final notifier = ChangeNotifier();
///
/// // Consumer subscribes:
/// notifier.getChangeToken().registerCallback(() => print('config changed'));
///
/// // Provider triggers a reload:
/// notifier.onReload();  // subscription callback fires
/// ```
final class ChangeNotifier {
  /// Creates a [ChangeNotifier] with an initial inactive [ReloadToken].
  ChangeNotifier() : _current = ReloadToken();

  ReloadToken _current;

  /// Returns the active [ChangeToken].
  ///
  /// Call this method **before** the event that may trigger a change to
  /// ensure the registration is in place when the token fires.
  ChangeToken getChangeToken() => _current;

  /// Rotates to a fresh [ReloadToken] and fires the previous one.
  ///
  /// All callbacks registered against the previous token are invoked
  /// synchronously in the order they were registered.
  void onReload() {
    final previous = _current;
    _current = ReloadToken();
    previous.notifyChanged();
  }
}
