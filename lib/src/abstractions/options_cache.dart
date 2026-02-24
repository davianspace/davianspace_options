/// A thread-safe, per-name cache of configured [T] instances used by
/// `OptionsMonitor`.
///
/// Analogous to `IOptionsMonitorCache<T>` from Microsoft.Extensions.Options.
///
/// Callers can:
/// - Retrieve an existing entry or create one atomically with [getOrAdd].
/// - Attempt to add an entry without overwriting an existing one via [tryAdd].
/// - Remove a single entry with [tryRemove] (triggering re-creation on next
///   access).
/// - Flush all entries at once with [clear] (e.g. on a full reload signal).
abstract interface class OptionsMonitorCache<T extends Object> {
  /// Returns the cached instance for [name], or creates and caches one by
  /// calling [createOptions] if the name is not yet present.
  ///
  /// The [createOptions] factory is invoked **at most once** per name on the
  /// happy path.
  T getOrAdd(String name, T Function() createOptions);

  /// Attempts to add [options] for [name].
  ///
  /// Returns `true` if the entry was inserted, `false` if [name] already
  /// had a cached value (the existing value is left unchanged).
  bool tryAdd(String name, T options);

  /// Removes the cached instance for [name].
  ///
  /// Returns `true` if the entry existed and was removed, `false` otherwise.
  bool tryRemove(String name);

  /// Removes all cached entries.
  void clear();
}
