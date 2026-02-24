/// davianspace_options
/// ─────────────────────────────────────────────────────────────────────────────
/// Enterprise-grade Options pattern for Dart/Flutter – conceptually equivalent
/// to Microsoft.Extensions.Options, expressed idiomatically in Dart.
///
/// ## Core abstractions
/// - `Options<T>`               – singleton-cached options access.
/// - `OptionsSnapshot<T>`       – scoped / per-request snapshot.
/// - `OptionsMonitor<T>`        – live options with change notifications.
/// - `OptionsFactory<T>`        – factory pipeline (configure → validate).
/// - `OptionsMonitorCache<T>`   – per-name instance cache used by the monitor.
/// - `ConfigureOptions<T>`      – registration interface for configure actions.
/// - `PostConfigureOptions<T>`  – registration interface for post-configure.
/// - `ValidateOptions<T>`       – registration interface for validators.
///
/// ## Core implementations
/// - `OptionsManager<T>`          – default `Options<T>` + `OptionsSnapshot<T>` impl.
/// - `OptionsMonitorImpl<T>`      – default `OptionsMonitor<T>` impl.
/// - `OptionsFactoryImpl<T>`      – default `OptionsFactory<T>` impl.
/// - `OptionsMonitorCacheImpl<T>` – default `OptionsMonitorCache<T>` impl.
///
/// ## Validation
/// - `ValidateOptionsResult`       – success / fail / skip discriminated value.
/// - `OptionsValidationException`  – aggregated validation failure.
///
/// ## Change tracking
/// - `ChangeToken`             – abstract single-use change signal.
/// - `ManualChangeToken`       – programmatically signalled token.
/// - `CompositeChangeToken`    – fires when any child token fires.
/// - `NeverChangeToken`        – sentinel that never fires.
/// - `OptionsChangeNotifier`   – manages per-name tokens for in-process reload.
///
/// ## Utilities / Builder
/// - `OptionsBuilder<T>`           – fluent builder for configure/validate.
/// - `ConfigureNamedOptions<T>`    – closure-based `ConfigureOptions<T>` impl.
/// - `PostConfigureNamedOptions<T>` – closure-based `PostConfigureOptions<T>` impl.
/// - `DelegateValidateOptions<T>`  – closure-based `ValidateOptions<T>` impl.

library;

// ── Abstractions ──────────────────────────────────────────────────────────────
export 'src/abstractions/configure_options.dart';
export 'src/abstractions/options.dart';
export 'src/abstractions/options_cache.dart';
export 'src/abstractions/options_factory.dart';
export 'src/abstractions/options_monitor.dart';
export 'src/abstractions/options_snapshot.dart';
export 'src/abstractions/post_configure_options.dart';
export 'src/abstractions/validate_options.dart';

// ── Change tracking ───────────────────────────────────────────────────────────
export 'src/change_tracking/change_notifier.dart';
export 'src/change_tracking/change_token.dart';

// ── Core  implementations ─────────────────────────────────────────────────────
export 'src/core/options_cache_impl.dart';
export 'src/core/options_factory_impl.dart';
export 'src/core/options_manager.dart';
export 'src/core/options_monitor_impl.dart';

// ── Utilities ─────────────────────────────────────────────────────────────────
export 'src/utils/named_options.dart';

// ── Validation ────────────────────────────────────────────────────────────────
export 'src/validation/validation_exception.dart';
export 'src/validation/validation_result.dart';
