/// Provides access to a singleton configuration instance of type [T].
///
/// Analogous to `IOptions<T>` from Microsoft.Extensions.Options.
///
/// The instance is created once at first access and cached for the lifetime
/// of the application. Use `OptionsSnapshot` for scoped/per-request semantics
/// and `OptionsMonitor` when you need live change notifications.
///
/// Example:
/// ```dart
/// final `Options<DatabaseOptions>` options = ...;
/// final db = options.value; // always the same instance
/// ```
abstract interface class Options<T extends Object> {
  /// The default options name used when no explicit name is provided.
  static const String defaultName = '';

  /// Returns the configured options instance.
  ///
  /// The instance is constructed lazily on first access and cached permanently.
  T get value;
}
