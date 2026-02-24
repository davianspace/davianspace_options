import '../validation/validation_result.dart';

/// Validates options of type [T] after the full configuration pipeline.
///
/// Analogous to `IValidateOptions<T>` from Microsoft.Extensions.Options.
///
/// Validators are invoked by `OptionsFactory` after all configure and
/// post-configure actions. All registered validators run; failures are
/// aggregated and surfaced together as an `OptionsValidationException`.
///
/// Return `ValidateOptionsResult.skip` when the validator does not apply
/// to the given `name` (e.g. it is scoped to a different named instance).
///
/// Example:
/// ```dart
/// class DatabaseOptionsValidator implements `ValidateOptions<DatabaseOptions>` {
///   @override
///   String? get name => null; // validate all instances
///
///   @override
///   `ValidateOptionsResult` validate(String name, `DatabaseOptions` options) {
///     if (options.connectionString.isEmpty) {
///       return `ValidateOptionsResult.fail`(
///         'DatabaseOptions[$name]: connectionString must not be empty.',
///       );
///     }
///     return `ValidateOptionsResult.success`();
///   }
/// }
/// ```
abstract interface class ValidateOptions<T extends Object> {
  /// The options name this validator targets.
  ///
  /// `null` means validate every named instance; a specific string means
  /// validate only instances with that exact name.
  String? get name;

  /// Validates [options] that were produced for [name].
  ///
  /// Returns one of:
  /// - [ValidateOptionsResult.success] – validation passed.
  /// - [ValidateOptionsResult.fail]    – validation failed with messages.
  /// - [ValidateOptionsResult.skip]    – this validator does not apply.
  ValidateOptionsResult validate(String name, T options);
}
