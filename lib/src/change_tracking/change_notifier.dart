import 'change_token.dart';

/// Manages `ManualChangeToken`s per options name and drives reloads inside
/// `OptionsMonitor`.
///
/// Each options name has exactly one "current" `ManualChangeToken`. When a
/// reload is triggered (by the application or an external source):
///
/// 1. Call `notifyChange` with the affected `name`.
/// 2. The current token fires all its registered callbacks.
/// 3. A fresh `ManualChangeToken` is installed for the next round.
///
/// This class is **not** coupled to any specific configuration source –
/// callers decide when to trigger reloads.
///
/// Example (in-memory reload):
/// ```dart
/// final notifier = OptionsChangeNotifier();
///
/// // Somewhere in your app when config changes:
/// notifier.notifyChange('database');   // fires listeners & resets token
/// ```
final class OptionsChangeNotifier {
  /// Creates a new [OptionsChangeNotifier] with an empty token registry.
  ///
  /// Call [getChangeToken] to obtain or lazily create a [ManualChangeToken]
  /// for a given options name, and [notifyChange] to fire it and install a
  /// replacement.
  OptionsChangeNotifier();

  final Map<String, ManualChangeToken> _tokens = {};

  /// Returns the current [ChangeToken] for [name].
  ///
  /// The returned token remains valid until the next call to
  /// [notifyChange] for the same [name].
  ChangeToken getChangeToken(String name) {
    return _tokens.putIfAbsent(name, ManualChangeToken.new);
  }

  /// Signals that options for [name] have changed.
  ///
  /// - Fires all callbacks registered on the current token for [name].
  /// - Replaces the active token with a fresh one for subsequent listeners.
  ///
  /// Calling [notifyChange] without any registered listeners is harmless.
  void notifyChange(String name) {
    final existing = _tokens[name];
    // Install fresh token before notifying so that any callback that
    // immediately registers a new listener gets the new token.
    _tokens[name] = ManualChangeToken();
    existing?.notifyChanged();
  }

  /// Signals a change for **every** options name that currently has a token.
  ///
  /// Useful on wholesale configuration reloads.
  void notifyAll() {
    final names = List<String>.of(_tokens.keys);
    for (final name in names) {
      notifyChange(name);
    }
  }
}
