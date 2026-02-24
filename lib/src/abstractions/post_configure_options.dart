/// Registers a post-configuration action for options of type [T].
///
/// Analogous to `IPostConfigureOptions<T>` from Microsoft.Extensions.Options.
///
/// Post-configure actions run **after** all `ConfigureOptions` actions have
/// been applied. This makes them suitable for cross-cutting concerns such as
/// defaults, coercion, or environment-specific overrides that should always
/// win regardless of other configuration.
///
/// Like `ConfigureOptions`, `name` can be `null` (apply to all) or a
/// specific string.
///
/// Example:
/// ```dart
/// `PostConfigureOptions<LoggingOptions>`(
///   postConfigure: (opts) {
///     // Ensure production builds never use verbose logging.
///     if (kReleaseMode) opts.level = LogLevel.warning;
///   },
/// );
/// ```
abstract interface class PostConfigureOptions<T extends Object> {
  /// The options name this registration targets.
  ///
  /// `null` means apply to every named instance; an empty string targets the
  /// default instance only.
  String? get name;

  /// Applies post-configuration mutations to [options].
  void postConfigure(T options);
}
