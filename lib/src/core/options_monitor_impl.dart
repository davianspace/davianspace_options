import '../abstractions/options.dart';
import '../abstractions/options_factory.dart';
import '../abstractions/options_monitor.dart';
import '../change_tracking/change_notifier.dart';
import '../change_tracking/change_token.dart';
import 'options_cache_impl.dart';

// =============================================================================
// OptionsMonitorImpl
// =============================================================================

/// Default implementation of [OptionsMonitor].
///
/// Responsibilities:
/// - Caches one [T] instance per name using [OptionsMonitorCacheImpl].
/// - Registers a listener on the [OptionsChangeNotifier] (or an external
///   [OptionsChangeTokenSource] list) for each name accessed.
/// - On reload: clears the cached entry, recreates via [OptionsFactory], and
///   dispatches to all subscribed listeners.
///
/// ### Change source wiring
///
/// Supply an [OptionsChangeNotifier] (the simple in-process notifier) **or**
/// a custom list of [OptionsChangeTokenSource]s (for file-watch, etc.).
/// Both mechanisms ultimately call [_reloadAndNotify] when a token fires.
///
/// ### Disposal
///
/// Call [dispose] when the monitor is no longer needed to cancel all active
/// [ChangeToken] subscriptions and clear listeners.
///
/// ```dart
/// final notifier = OptionsChangeNotifier();
/// final monitor  = OptionsMonitorImpl<AppSettings>(
///   factory:  myFactory,
///   notifier: notifier,
/// );
///
/// final reg = monitor.onChange((settings, name) {
///   print('$name updated → ${settings.theme}');
/// });
///
/// // Trigger a reload from anywhere:
/// notifier.notifyChange(Options.defaultName);
///
/// // Cleanup:
/// reg.dispose();
/// monitor.dispose();
/// ```
final class OptionsMonitorImpl<T extends Object> implements OptionsMonitor<T> {
  /// Creates the monitor.
  ///
  /// [factory]          – Used to produce new [T] instances after a reload.
  /// [notifier]         – Optional in-process change notifier.
  /// [tokenSources]     – Optional external token sources.
  ///
  /// At least one of [notifier] or [tokenSources] should be provided to
  /// receive change notifications.  If neither is provided the monitor still
  /// works but will never automatically reload.
  OptionsMonitorImpl({
    required OptionsFactory<T> factory,
    OptionsChangeNotifier? notifier,
    List<OptionsChangeTokenSource<T>> tokenSources = const [],
  })  : _factory = factory,
        _notifier = notifier,
        _tokenSources = List.unmodifiable(tokenSources),
        _cache = OptionsMonitorCacheImpl<T>() {
    // Pre-wire the default name so that onChange callbacks registered before
    // any get() call still receive notifications for Options.defaultName.
    _wireNotifierForName(Options.defaultName);
    _wireTokenSources();
  }

  final OptionsFactory<T> _factory;
  final OptionsChangeNotifier? _notifier;
  final List<OptionsChangeTokenSource<T>> _tokenSources;
  final OptionsMonitorCacheImpl<T> _cache;

  // Active listener list: List<(T, String) -> void>
  final List<void Function(T, String)> _listeners = [];

  // ChangeToken registrations from external sources that we must dispose.
  final List<ChangeTokenRegistration> _tokenRegistrations = [];

  // Names for which we have wired notifier callbacks.
  final Set<String> _wiredNotifierNames = {};

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // OptionsMonitor<T>
  // ---------------------------------------------------------------------------

  @override
  T get currentValue => get(Options.defaultName);

  @override
  T get(String name) {
    _guardDisposed();
    // Wire notifier on first access per name.
    _wireNotifierForName(name);
    return _cache.getOrAdd(name, () => _factory.create(name));
  }

  @override
  OptionsChangeRegistration onChange(
    void Function(T options, String name) listener,
  ) {
    _guardDisposed();
    _listeners.add(listener);
    return _MonitorChangeRegistration<T>(_listeners, listener);
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Disposes all [ChangeToken] registrations and clears listeners.
  ///
  /// After disposal, [get] and [onChange] will throw [StateError].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final reg in _tokenRegistrations) {
      reg.dispose();
    }
    _tokenRegistrations.clear();
    _listeners.clear();
    _cache.clear();
  }

  // ---------------------------------------------------------------------------
  // Internal wiring
  // ---------------------------------------------------------------------------

  void _wireTokenSources() {
    for (final source in _tokenSources) {
      _attachTokenSource(source);
    }
  }

  void _attachTokenSource(OptionsChangeTokenSource<T> source) {
    final token = source.getChangeToken();
    final reg = token.registerCallback(
      () => _reloadAndNotify(source.name, source),
    );
    _tokenRegistrations.add(reg);
  }

  void _wireNotifierForName(String name) {
    if (_notifier == null) return;
    if (_wiredNotifierNames.contains(name)) return;
    _wiredNotifierNames.add(name);
    final notifier = _notifier!;

    // We poll getChangeToken() each time the previous token fires.
    void listenNext() {
      if (_disposed) return;
      final token = notifier.getChangeToken(name);
      final reg = token.registerCallback(() {
        if (_disposed) return;
        _reloadAndNotify(name, null);
        // Re-register for the *next* token after reload.
        listenNext();
      });
      _tokenRegistrations.add(reg);
    }

    listenNext();
  }

  /// Called when a change token fires for [name].
  ///
  /// 1. Evict the cached instance.
  /// 2. Create a new instance via the factory.
  /// 3. Notify all registered listeners.
  void _reloadAndNotify(String name, OptionsChangeTokenSource<T>? source) {
    if (_disposed) return;

    _cache.tryRemove(name);
    final updated = _cache.getOrAdd(name, () => _factory.create(name));

    // Re-wire external token source for subsequent changes.
    if (source != null) {
      _attachTokenSource(source);
    }

    final snapshot = List<void Function(T, String)>.of(_listeners);
    for (final listener in snapshot) {
      listener(updated, name);
    }
  }

  void _guardDisposed() {
    if (_disposed) {
      throw StateError(
        'OptionsMonitorImpl<$T> has been disposed and cannot be used.',
      );
    }
  }
}

// =============================================================================
// _MonitorChangeRegistration
// =============================================================================

final class _MonitorChangeRegistration<T extends Object>
    implements OptionsChangeRegistration {
  _MonitorChangeRegistration(this._list, this._listener);

  final List<void Function(T, String)> _list;
  final void Function(T, String) _listener;

  @override
  void dispose() => _list.remove(_listener);
}
