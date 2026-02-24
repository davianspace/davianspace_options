/// Propagates notifications that a change has occurred.
///
/// Modelled after `IChangeToken` (Microsoft.Extensions.Primitives) but
/// expressed idiomatically in Dart.
///
/// A [ChangeToken] is a **single-use** snapshot of change state:
/// - [hasChanged] starts as `false`.
/// - When the underlying source changes, the token transitions to
///   `hasChanged == true` permanently (tokens are not reset; callers
///   request a fresh token from the source after each change).
/// - [registerCallback] can be used to receive an eager notification
///   instead of polling.
///
/// Built-in implementations:
/// - [ManualChangeToken]   – programmatically signalled.
/// - [CompositeChangeToken] – fires when any child token changes.
/// - [NeverChangeToken]    – immutable sentinel that never fires.
abstract interface class ChangeToken {
  /// Whether this token has been signalled (the underlying source changed).
  bool get hasChanged;

  /// Registers a [callback] to be invoked when [hasChanged] becomes `true`.
  ///
  /// If the token has already changed at registration time the callback
  /// **may** be invoked synchronously or scheduled immediately on the
  /// microtask queue – callers must not depend on timing.
  ///
  /// The returned [ChangeTokenRegistration] can be disposed to prevent the
  /// callback from being called (best-effort; the callback may still fire
  /// once if it was already queued).
  ChangeTokenRegistration registerCallback(void Function() callback);
}

/// Represents a single [ChangeToken.registerCallback] subscription.
abstract interface class ChangeTokenRegistration {
  /// Removes this registration.
  void dispose();
}

// =============================================================================
// ManualChangeToken
// =============================================================================

/// A [ChangeToken] that is signalled explicitly by calling [notifyChanged].
///
/// Typical usage: hold one per options name in your `OptionsChangeNotifier`,
/// call `notifyChanged` when a reload occurs, then replace the token with a
/// fresh `ManualChangeToken` for the next notification round.
///
/// ```dart
/// final token = ManualChangeToken();
/// final reg   = token.registerCallback(() => print('changed!'));
/// token.notifyChanged(); // prints 'changed!'
/// reg.dispose();
/// ```
final class ManualChangeToken implements ChangeToken {
  /// Creates a new, unsignalled [ManualChangeToken].
  ///
  /// Call [notifyChanged] to signal the token and invoke all registered
  /// callbacks.
  ManualChangeToken();

  bool _hasChanged = false;
  final List<void Function()> _callbacks = [];

  @override
  bool get hasChanged => _hasChanged;

  @override
  ChangeTokenRegistration registerCallback(void Function() callback) {
    if (_hasChanged) {
      // Already changed – notify immediately via microtask.
      Future.microtask(callback);
      return _NoOpRegistration();
    }
    _callbacks.add(callback);
    return _CallbackRegistration(_callbacks, callback);
  }

  /// Signals that the underlying source has changed.
  ///
  /// All registered callbacks are invoked synchronously in registration order,
  /// then cleared. Subsequent [registerCallback] calls will schedule
  /// the callback immediately.
  void notifyChanged() {
    if (_hasChanged) return;
    _hasChanged = true;

    final snapshot = List<void Function()>.of(_callbacks);
    _callbacks.clear();
    for (final cb in snapshot) {
      cb();
    }
  }
}

// =============================================================================
// CompositeChangeToken
// =============================================================================

/// A [ChangeToken] that aggregates multiple child tokens and fires as soon
/// as any one of them changes.
///
/// Useful for watching several independent change sources (e.g. multiple
/// configuration files) through a single token.
final class CompositeChangeToken implements ChangeToken {
  /// Creates a composite token from [tokens].
  ///
  /// [tokens] must not be empty.
  CompositeChangeToken(List<ChangeToken> tokens)
      : assert(tokens.isNotEmpty, 'tokens must not be empty'),
        _tokens = List.unmodifiable(tokens);

  final List<ChangeToken> _tokens;
  bool _hasChanged = false;
  final List<void Function()> _callbacks = [];
  final List<ChangeTokenRegistration> _childRegistrations = [];

  /// Lazily attaches child registrations on first access.
  void _ensureListening() {
    if (_childRegistrations.isNotEmpty) return;
    for (final t in _tokens) {
      _childRegistrations.add(t.registerCallback(_onChildChanged));
    }
  }

  void _onChildChanged() {
    if (_hasChanged) return;
    _hasChanged = true;
    for (final reg in _childRegistrations) {
      reg.dispose();
    }
    _childRegistrations.clear();
    final snapshot = List<void Function()>.of(_callbacks);
    _callbacks.clear();
    for (final cb in snapshot) {
      cb();
    }
  }

  @override
  bool get hasChanged {
    if (_hasChanged) return true;
    // Eagerly check children without registering callbacks.
    return _tokens.any((t) => t.hasChanged);
  }

  @override
  ChangeTokenRegistration registerCallback(void Function() callback) {
    if (hasChanged) {
      Future.microtask(callback);
      return _NoOpRegistration();
    }
    _ensureListening();
    _callbacks.add(callback);
    return _CallbackRegistration(_callbacks, callback);
  }
}

// =============================================================================
// NeverChangeToken
// =============================================================================

/// A sentinel `ChangeToken` that never fires.
///
/// Use it as a no-op token when a `OptionsChangeTokenSource` does not
/// support change notifications.
final class NeverChangeToken implements ChangeToken {
  /// The singleton instance.
  static const NeverChangeToken instance = NeverChangeToken._();

  const NeverChangeToken._();

  @override
  bool get hasChanged => false;

  @override
  ChangeTokenRegistration registerCallback(void Function() callback) =>
      _NoOpRegistration();
}

// =============================================================================
// Internal helpers
// =============================================================================

final class _NoOpRegistration implements ChangeTokenRegistration {
  @override
  void dispose() {}
}

final class _CallbackRegistration implements ChangeTokenRegistration {
  _CallbackRegistration(this._list, this._callback);

  final List<void Function()> _list;
  final void Function() _callback;

  @override
  void dispose() => _list.remove(_callback);
}
