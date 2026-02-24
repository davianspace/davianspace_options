/// Provides access to named configuration instances of type [T], with
/// scoped lifetime semantics.
///
/// Analogous to `IOptionsSnapshot<T>` from Microsoft.Extensions.Options.
///
/// A snapshot is immutable within a logical "scope" (e.g. a request, a unit
/// of work, a test case). Each new scope receives freshly created instances
/// that reflect the configuration state at the moment the scope was opened.
///
/// Use `OptionsMonitor` when you need cross-scope live change notifications.
///
/// Example:
/// ```dart
/// final `OptionsSnapshot<FeatureFlags>` snapshot = ...;
/// final flags = snapshot.value;               // default name
/// final beta  = snapshot.get('betaFeatures'); // named
/// ```
abstract interface class OptionsSnapshot<T extends Object> {
  /// Returns the options instance for the default name `Options.defaultName`.
  T get value;

  /// Returns the options instance registered under `name`.
  ///
  /// Throws `ArgumentError` if `name` is empty and the caller intended a
  /// named lookup (use `value` instead for the default instance).
  T get(String name);
}
