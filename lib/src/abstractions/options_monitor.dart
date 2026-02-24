import '../change_tracking/change_token.dart';

/// Provides live access to named configuration instances of type [T] and
/// raises notifications whenever configuration changes.
///
/// Analogous to `IOptionsMonitor<T>` from Microsoft.Extensions.Options.
///
/// Unlike `Options` (which is permanently cached) and `OptionsSnapshot`
/// (which is scoped), `OptionsMonitor` reflects the **current** options state
/// and notifies listeners through `onChange` when that state is reloaded.
///
/// Dispose the returned `OptionsChangeRegistration` when you no longer need
/// the callback to prevent memory leaks.
///
/// Example:
/// ```dart
/// final `OptionsMonitor<AppSettings>` monitor = ...;
///
/// final reg = monitor.onChange((opts, name) {
///   print('$name changed: ${opts.debugLabel}');
/// });
///
/// // ...later...
/// reg.dispose();
/// ```
abstract interface class OptionsMonitor<T extends Object> {
  /// Returns the current options instance for the default name.
  T get currentValue;

  /// Returns the current options instance registered under [name].
  T get(String name);

  /// Registers a listener to be called whenever options of type [T] change.
  ///
  /// The callback receives the updated [T] instance and the options `name`
  /// that changed.
  ///
  /// Returns an [OptionsChangeRegistration] which, when disposed, removes
  /// the listener. **Always dispose** unused registrations.
  OptionsChangeRegistration onChange(
    void Function(T options, String name) listener,
  );
}

/// Represents a change-notification subscription returned by
/// [OptionsMonitor.onChange].
///
/// Call [dispose] to stop receiving notifications and release resources.
abstract interface class OptionsChangeRegistration {
  /// Unsubscribes from change notifications.
  void dispose();
}

/// Internal extension point: sources that can produce [ChangeToken]s
/// (e.g. file watchers, in-memory reloaders) implement this to drive
/// [OptionsMonitor] reloads.
abstract interface class OptionsChangeTokenSource<T extends Object> {
  /// Produces the [ChangeToken] for this source.
  ChangeToken getChangeToken();

  /// The options name this source is associated with.
  ///
  /// Use `Options.defaultName` (the empty string) for the default instance.
  String get name;
}
