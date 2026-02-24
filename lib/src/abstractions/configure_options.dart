/// Registers a configuration action for options of type [T].
///
/// Analogous to `IConfigureOptions<T>` / `IConfigureNamedOptions<T>` from
/// Microsoft.Extensions.Options.
///
/// Configuration actions are applied by `OptionsFactory` **before**
/// post-configure actions. Multiple registrations are applied in the order
/// they were registered.
///
/// When [name] is `null` the action applies to **all** named instances.
/// When [name] is a non-null string it applies **only** to the instance with
/// that exact name (use `Options.defaultName` for the unnamed instance).
///
/// Example – apply to all names:
/// ```dart
/// ConfigureOptions<DatabaseOptions>(
///   configure: (opts) => opts.timeout = const Duration(seconds: 30),
/// );
/// ```
///
/// Example – apply only to the named instance:
/// ```dart
/// ConfigureOptions<DatabaseOptions>(
///   name: 'replica',
///   configure: (opts) => opts.host = 'replica.db.example.com',
/// );
/// ```
abstract interface class ConfigureOptions<T extends Object> {
  /// The options name this registration targets.
  ///
  /// A `null` value means the action is applied to **every** named instance.
  /// An empty string (`''`) targets the default (unnamed) instance only.
  String? get name;

  /// Applies configuration mutations to [options].
  void configure(T options);
}
