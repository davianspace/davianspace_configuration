/// A one-shot, manually-triggered [ChangeToken].
///
/// [ReloadToken] is the concrete change token created by configuration
/// providers each time they need to signal a reload.  Once
/// [notifyChanged] is called, every registered callback fires immediately
/// (synchronously) and [hasChanged] becomes permanently `true`.  A new
/// [ReloadToken] must be created for subsequent change notifications.
library;

import 'change_token.dart';

/// A manually-triggered, single-use change token.
///
/// Providers create a new [ReloadToken] at construction time and replace it
/// with a fresh one **before** firing the previous token so that a listener
/// calling `getReloadToken()` during the callback always receives the new
/// token.
///
/// ```dart
/// // Inside a ConfigurationProvider subclass:
/// ReloadToken _reloadToken = ReloadToken();
///
/// @override
/// ChangeToken getReloadToken() => _reloadToken;
///
/// void _triggerReload() {
///   final previous = _reloadToken;
///   _reloadToken = ReloadToken();   // replace before firing
///   previous.notifyChanged();       // fire callbacks on previous token
/// }
/// ```
final class ReloadToken implements ChangeToken {
  /// Creates a new, un-triggered [ReloadToken].
  ReloadToken();

  bool _hasChanged = false;
  final List<void Function()> _callbacks = [];

  @override
  bool get hasChanged => _hasChanged;

  @override
  bool get activeChangeCallbacks => true;

  /// Triggers this token: sets [hasChanged] to `true` and synchronously
  /// invokes every registered callback.
  ///
  /// Subsequent calls to [notifyChanged] on the same token are no-ops.
  void notifyChanged() {
    if (_hasChanged) return;
    _hasChanged = true;
    // Take a snapshot so callbacks that dispose their own registration do not
    // mutate the list while we are iterating.
    final snapshot = List<void Function()>.unmodifiable(_callbacks);
    _callbacks.clear();
    for (final cb in snapshot) {
      cb();
    }
  }

  @override
  TokenRegistration registerCallback(void Function() callback) {
    if (_hasChanged) {
      // Already triggered — fire immediately and return a no-op registration.
      callback();
      return TokenRegistration.empty;
    }
    _callbacks.add(callback);
    return TokenRegistration(() => _callbacks.remove(callback));
  }
}
