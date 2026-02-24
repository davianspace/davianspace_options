import '../abstractions/options_cache.dart';

/// Default in-process implementation of [OptionsMonitorCache].
///
/// Stores one instance per options name in a [Map] guarded by synchronous
/// operations (safe in Dart's single-threaded isolate model).
///
/// Entries are added lazily on first access via [getOrAdd] and can be
/// invalidated individually with [tryRemove] or wholesale with [clear].
final class OptionsMonitorCacheImpl<T extends Object>
    implements OptionsMonitorCache<T> {
  /// Creates an empty, in-process [OptionsMonitorCache] for type [T].
  ///
  /// Entries are created lazily via [getOrAdd] and can be evicted with
  /// [tryRemove] or [clear].
  OptionsMonitorCacheImpl();

  final Map<String, T> _cache = {};

  // ---------------------------------------------------------------------------
  // OptionsMonitorCache<T>
  // ---------------------------------------------------------------------------

  /// Returns the cached [T] for [name], or calls [createOptions] to create and
  /// cache a new instance when the name is absent.
  ///
  /// [createOptions] is called synchronously and its return value is stored
  /// immediately, so it will not be called twice for the same [name] in
  /// normal usage.
  @override
  T getOrAdd(String name, T Function() createOptions) {
    final existing = _cache[name];
    if (existing != null) return existing;

    final created = createOptions();
    _cache[name] = created;
    return created;
  }

  /// Attempts to store [options] under [name].
  ///
  /// Returns `true` if the entry was inserted, `false` if [name] was already
  /// present.
  @override
  bool tryAdd(String name, T options) {
    if (_cache.containsKey(name)) return false;
    _cache[name] = options;
    return true;
  }

  /// Removes the cached instance for [name].
  ///
  /// Returns `true` if an entry was removed; `false` if [name] was absent.
  @override
  bool tryRemove(String name) {
    if (!_cache.containsKey(name)) return false;
    _cache.remove(name);
    return true;
  }

  /// Removes all cached entries.
  @override
  void clear() => _cache.clear();

  /// The number of currently cached entries.
  int get length => _cache.length;

  /// Whether the cache contains an entry for [name].
  bool containsKey(String name) => _cache.containsKey(name);
}
