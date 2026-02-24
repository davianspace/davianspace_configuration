/// Change-token abstractions used to track configuration mutations and
/// propagate reload signals without polling.
library;

/// A token that signals when a watched resource has changed.
///
/// Consumers register callbacks via [registerCallback]; the token calls each
/// registered callback exactly once when the underlying source changes and
/// the token transitions to the [hasChanged] state.
///
/// Tokens are single-use: once [hasChanged] is `true`, a new token must be
/// obtained from the originating source to watch for subsequent changes.
///
/// Inspired by `Microsoft.Extensions.Primitives.IChangeToken`.
abstract interface class ChangeToken {
  /// Whether the watched resource has changed since this token was issued.
  ///
  /// Once `true`, this value does not revert to `false`.
  bool get hasChanged;

  /// Whether this token will actively invoke registered callbacks when it
  /// changes, as opposed to requiring the consumer to poll [hasChanged].
  ///
  /// When `false`, consumers **must** poll [hasChanged] themselves.
  bool get activeChangeCallbacks;

  /// Registers [callback] to be invoked when the token transitions to
  /// the changed state.
  ///
  /// Returns a [TokenRegistration] whose [TokenRegistration.dispose] method
  /// removes the registration.  Dispose the registration when it is no longer
  /// needed to prevent memory leaks.
  ///
  /// When [activeChangeCallbacks] is `false` the registration is a no-op, but
  /// the returned [TokenRegistration] is still safe to dispose.
  TokenRegistration registerCallback(void Function() callback);
}

/// A handle to a callback registered with a [ChangeToken].
///
/// Call [dispose] to deregister the callback and release resources.
final class TokenRegistration {
  /// Creates a token registration backed by [_dispose].
  const TokenRegistration(this._dispose);

  /// A registration that does nothing when disposed.
  static const TokenRegistration empty = TokenRegistration(_noOp);
  static void _noOp() {}

  final void Function() _dispose;

  /// Removes this registration from its originating [ChangeToken].
  void dispose() => _dispose();
}

/// A [ChangeToken] that never changes.
///
/// Useful as a null-object: providers that do not support reload return a
/// [NeverChangeToken] from `getReloadToken()`.
final class NeverChangeToken implements ChangeToken {
  /// The singleton never-changing token.
  const NeverChangeToken();

  @override
  bool get hasChanged => false;

  @override
  bool get activeChangeCallbacks => false;

  @override
  TokenRegistration registerCallback(void Function() callback) =>
      TokenRegistration.empty;
}
