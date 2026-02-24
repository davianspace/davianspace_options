import '../abstractions/options.dart';
import '../abstractions/options_factory.dart';
import '../abstractions/options_snapshot.dart';

// =============================================================================
// OptionsManager  (implements both Options<T> and OptionsSnapshot<T>)
// =============================================================================

/// Concrete implementation of both [Options] and [OptionsSnapshot].
///
/// ### As [Options]
/// The first call to [value] (or [get] for the default name) triggers lazy
/// construction via [OptionsFactory.create]. The result is cached
/// **permanently** for the lifetime of this manager – the underlying instance
/// is never recreated even if configuration sources change.
///
/// ### As [OptionsSnapshot]
/// When used in a scoped pattern, create one [OptionsManager] per scope.
/// Within that scope every call to [get] returns the **same** cached instance
/// for a given name, meaning the snapshot is stable within the scope but a new
/// scope (new [OptionsManager]) will pick up the latest configuration.
///
/// ```dart
/// // Singleton usage (Options<T>):
/// final opts = OptionsManager<AppSettings>(factory: factory);
/// final settings = opts.value; // created once, cached forever
///
/// // Scoped usage (OptionsSnapshot<T>):
/// void handleRequest(OptionsManager<FeatureFlags> snapshot) {
///   final flags = snapshot.get('beta'); // same object for this scope
/// }
/// ```
final class OptionsManager<T extends Object>
    implements Options<T>, OptionsSnapshot<T> {
  /// Creates a manager backed by [factory].
  OptionsManager({required OptionsFactory<T> factory}) : _factory = factory;

  final OptionsFactory<T> _factory;
  final Map<String, T> _cache = {};

  // ---------------------------------------------------------------------------
  // Options<T>
  // ---------------------------------------------------------------------------

  @override
  T get value => get(Options.defaultName);

  // ---------------------------------------------------------------------------
  // OptionsSnapshot<T>
  // ---------------------------------------------------------------------------

  @override
  T get(String name) => _cache.putIfAbsent(name, () => _factory.create(name));
}
