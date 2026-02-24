import '../abstractions/configure_options.dart';
import '../abstractions/options.dart';
import '../abstractions/post_configure_options.dart';
import '../abstractions/validate_options.dart';
import '../validation/validation_result.dart';

// =============================================================================
// ConfigureNamedOptions
// =============================================================================

/// A closure-based implementation of [ConfigureOptions] that targets a
/// specific [name] (or all names when [name] is `null`).
///
/// This is the primary concrete type produced by [OptionsBuilder.configure] and
/// [OptionsBuilder.configureNamed]; direct construction is also supported.
///
/// ```dart
/// // Applies to every instance of T:
/// ConfigureNamedOptions<MyOptions>(
///   name: null,
///   configure: (opts) => opts.value = 42,
/// );
///
/// // Applies only to the 'production' instance:
/// ConfigureNamedOptions<MyOptions>(
///   name: 'production',
///   configure: (opts) => opts.value = 100,
/// );
/// ```
final class ConfigureNamedOptions<T extends Object>
    implements ConfigureOptions<T> {
  /// Creates a configure registration.
  ///
  /// [name] – the options name to target, or `null` to target every name.
  /// [configure] – the mutation callback.
  const ConfigureNamedOptions({
    required this.name,
    required void Function(T options) configure,
  }) : _configure = configure;

  @override
  final String? name;

  final void Function(T options) _configure;

  @override
  void configure(T options) => _configure(options);
}

// =============================================================================
// PostConfigureNamedOptions
// =============================================================================

/// A closure-based implementation of [PostConfigureOptions] that targets a
/// specific [name] (or all names when [name] is `null`).
///
/// ```dart
/// PostConfigureNamedOptions<MyOptions>(
///   name: null,
///   postConfigure: (opts) => opts.isSealed = true,
/// );
/// ```
final class PostConfigureNamedOptions<T extends Object>
    implements PostConfigureOptions<T> {
  /// Creates a post-configure registration.
  ///
  /// [name] – the options name to target, or `null` to target every name.
  /// [postConfigure] – the mutation callback.
  const PostConfigureNamedOptions({
    required this.name,
    required void Function(T options) postConfigure,
  }) : _postConfigure = postConfigure;

  @override
  final String? name;

  final void Function(T options) _postConfigure;

  @override
  void postConfigure(T options) => _postConfigure(options);
}

// =============================================================================
// DelegateValidateOptions
// =============================================================================

/// A closure-based implementation of [ValidateOptions].
///
/// ```dart
/// DelegateValidateOptions<MyOptions>(
///   name: null,
///   validate: (name, opts) => opts.port > 0
///       ? ValidateOptionsResult.success()
///       : ValidateOptionsResult.fail('port must be > 0'),
/// );
/// ```
final class DelegateValidateOptions<T extends Object>
    implements ValidateOptions<T> {
  /// Creates a validate registration.
  ///
  /// [name] – the options name to target, or `null` to target every name.
  /// [validate] – the validation callback.
  const DelegateValidateOptions({
    required this.name,
    required ValidateOptionsResult Function(String name, T options) validate,
  }) : _validate = validate;

  @override
  final String? name;

  final ValidateOptionsResult Function(String name, T options) _validate;

  @override
  ValidateOptionsResult validate(String name, T options) =>
      _validate(name, options);
}

// =============================================================================
// OptionsBuilder
// =============================================================================

/// A fluent builder that collects configure, post-configure, and validate
/// registrations for a single options type [T], then produces the lists
/// consumed by `OptionsFactoryImpl`.
///
/// This API is the **primary integration point** for application code and DI
/// container adapters.
///
/// Example:
/// ```dart
/// final builder = OptionsBuilder<DatabaseOptions>(
///   factory: DatabaseOptions.new,
/// );
///
/// builder
///   .configure((opts) => opts.host = 'localhost')
///   .configureNamed('replica', (opts) => opts.host = 'replica.example.com')
///   .postConfigure((opts) => opts.connectionString = opts.buildUri())
///   .validate(
///     (name, opts) => opts.host.isNotEmpty
///         ? ValidateOptionsResult.success()
///         : ValidateOptionsResult.fail('$name: host is required'),
///   );
/// ```
final class OptionsBuilder<T extends Object> {
  /// Creates a builder with an instance [factory].
  ///
  /// The [factory] must return a **new, mutable** [T] each time it is called.
  OptionsBuilder({required T Function() factory}) : _factory = factory;

  final T Function() _factory;
  final List<ConfigureOptions<T>> _configureActions = [];
  final List<PostConfigureOptions<T>> _postConfigureActions = [];
  final List<ValidateOptions<T>> _validators = [];

  // ---------------------------------------------------------------------------
  // Configure
  // ---------------------------------------------------------------------------

  /// Registers [action] to run against every instance of [T] (all names).
  OptionsBuilder<T> configure(void Function(T options) action) {
    _configureActions.add(
      ConfigureNamedOptions<T>(name: null, configure: action),
    );
    return this;
  }

  /// Registers [action] to run only against the instance named [name].
  ///
  /// Use [Options.defaultName] (the empty string) to target the default
  /// (unnamed) instance.
  OptionsBuilder<T> configureNamed(
    String name,
    void Function(T options) action,
  ) {
    _configureActions.add(
      ConfigureNamedOptions<T>(name: name, configure: action),
    );
    return this;
  }

  // ---------------------------------------------------------------------------
  // Post-configure
  // ---------------------------------------------------------------------------

  /// Registers [action] to run **after** all configure actions, for every
  /// instance.
  OptionsBuilder<T> postConfigure(void Function(T options) action) {
    _postConfigureActions.add(
      PostConfigureNamedOptions<T>(name: null, postConfigure: action),
    );
    return this;
  }

  /// Registers [action] to run **after** all configure actions, only for [name].
  OptionsBuilder<T> postConfigureNamed(
    String name,
    void Function(T options) action,
  ) {
    _postConfigureActions.add(
      PostConfigureNamedOptions<T>(name: name, postConfigure: action),
    );
    return this;
  }

  // ---------------------------------------------------------------------------
  // Validate
  // ---------------------------------------------------------------------------

  /// Registers a [validator] callback for every instance of [T].
  ///
  /// Return [ValidateOptionsResult.success] or [ValidateOptionsResult.fail].
  OptionsBuilder<T> validate(
    ValidateOptionsResult Function(String name, T options) validator,
  ) {
    _validators.add(
      DelegateValidateOptions<T>(name: null, validate: validator),
    );
    return this;
  }

  /// Registers a [validator] callback only for the named instance [name].
  OptionsBuilder<T> validateNamed(
    String name,
    ValidateOptionsResult Function(String name, T options) validator,
  ) {
    _validators.add(
      DelegateValidateOptions<T>(name: name, validate: validator),
    );
    return this;
  }

  // ---------------------------------------------------------------------------
  // Accessors used by OptionsFactoryImpl
  // ---------------------------------------------------------------------------

  /// The registered factory function.
  T Function() get factory => _factory;

  /// All configure registrations in order of registration.
  List<ConfigureOptions<T>> get configureActions =>
      List.unmodifiable(_configureActions);

  /// All post-configure registrations in order of registration.
  List<PostConfigureOptions<T>> get postConfigureActions =>
      List.unmodifiable(_postConfigureActions);

  /// All validate registrations in order of registration.
  List<ValidateOptions<T>> get validators => List.unmodifiable(_validators);
}
