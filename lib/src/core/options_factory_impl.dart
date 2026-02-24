import '../abstractions/configure_options.dart';
import '../abstractions/options.dart';
import '../abstractions/options_factory.dart';
import '../abstractions/post_configure_options.dart';
import '../abstractions/validate_options.dart';
import '../validation/validation_exception.dart';

/// Default implementation of [OptionsFactory].
///
/// Runs the full configuration pipeline whenever [create] is called:
///
/// 1. **Instantiation** – calls [_instanceFactory] to produce a fresh [T].
/// 2. **Configure** – applies every `ConfigureOptions` whose `name` is `null`
///    or matches the requested `name`.
/// 3. **PostConfigure** – applies every `PostConfigureOptions` with the same
///    name-matching logic.
/// 4. **Validate** – runs all [ValidateOptions] registrations, accumulates
///    failures, and throws [OptionsValidationException] if any validator
///    reported failure (non-skipped).
///
/// All steps execute synchronously within the calling isolate. There is no
/// caching here – caching is the responsibility of callers such as
/// `OptionsMonitorCacheImpl`.
final class OptionsFactoryImpl<T extends Object> implements OptionsFactory<T> {
  /// Creates the factory.
  ///
  /// [instanceFactory] – produces a fresh, mutable [T].
  /// [configureOptions] – ordered configure registrations (may be empty).
  /// [postConfigureOptions] – ordered post-configure registrations.
  /// [validators] – ordered validate registrations.
  OptionsFactoryImpl({
    required T Function() instanceFactory,
    List<ConfigureOptions<T>> configureOptions = const [],
    List<PostConfigureOptions<T>> postConfigureOptions = const [],
    List<ValidateOptions<T>> validators = const [],
  })  : _instanceFactory = instanceFactory,
        _configureOptions = List.unmodifiable(configureOptions),
        _postConfigureOptions = List.unmodifiable(postConfigureOptions),
        _validators = List.unmodifiable(validators);

  final T Function() _instanceFactory;
  final List<ConfigureOptions<T>> _configureOptions;
  final List<PostConfigureOptions<T>> _postConfigureOptions;
  final List<ValidateOptions<T>> _validators;

  // ---------------------------------------------------------------------------
  // OptionsFactory<T>
  // ---------------------------------------------------------------------------

  @override
  T create(String name) {
    final options = _instanceFactory();

    // ---- 1. Configure -------------------------------------------------------
    for (final configure in _configureOptions) {
      if (configure.name == null || configure.name == name) {
        configure.configure(options);
      }
    }

    // ---- 2. PostConfigure ---------------------------------------------------
    for (final postConfigure in _postConfigureOptions) {
      if (postConfigure.name == null || postConfigure.name == name) {
        postConfigure.postConfigure(options);
      }
    }

    // ---- 3. Validate (aggregate all failures) -------------------------------
    final failures = <String>[];
    for (final validator in _validators) {
      if (validator.name != null && validator.name != name) continue;

      final result = validator.validate(name, options);
      if (result.failed) {
        failures.addAll(result.failures);
      }
    }

    if (failures.isNotEmpty) {
      throw OptionsValidationException(
        optionsType: T,
        optionsName: name,
        failures: failures,
      );
    }

    return options;
  }
}

/// A convenience subclass that derives its name-filtering logic from
/// [Options.defaultName], making the default-name idiom obvious at the
/// call site.
extension OptionsFactoryExtensions<T extends Object> on OptionsFactory<T> {
  /// Calls [create] with [Options.defaultName].
  T createDefault() => create(Options.defaultName);
}
