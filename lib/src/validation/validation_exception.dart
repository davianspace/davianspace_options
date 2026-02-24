/// Thrown by `OptionsFactory.create` when one or more `ValidateOptions`
/// registrations report failure.
///
/// All accumulated failure messages from every failing validator are included
/// in a single exception so callers see the complete picture immediately
/// rather than having to fix one error at a time.
///
/// Example:
/// ```dart
/// try {
///   final opts = factory.create(Options.defaultName);
/// } on OptionsValidationException catch (e) {
///   for (final msg in e.failures) {
///     log.error(msg);
///   }
/// }
/// ```
final class OptionsValidationException implements Exception {
  /// Creates the exception with the given [optionsType], [optionsName], and
  /// the list of non-empty [failures].
  OptionsValidationException({
    required this.optionsType,
    required this.optionsName,
    required List<String> failures,
  })  : assert(failures.isNotEmpty, 'failures must not be empty'),
        failures = List.unmodifiable(failures);

  /// The Dart [Type] of the options class that failed validation.
  final Type optionsType;

  /// The name of the options instance that failed validation.
  ///
  /// Will be the empty string for the default (unnamed) instance.
  final String optionsName;

  /// Human-readable descriptions of every validation failure.
  ///
  /// Always contains at least one entry.
  final List<String> failures;

  @override
  String toString() {
    final label =
        optionsName.isEmpty ? '$optionsType' : '$optionsType[$optionsName]';
    final msgs = failures.map((f) => '  • $f').join('\n');
    return 'OptionsValidationException: $label failed validation:\n$msgs';
  }
}
