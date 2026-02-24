/// Represents the outcome of a single `ValidateOptions` check.
///
/// Use the named constructors to produce results:
/// - `ValidateOptionsResult.success` – the options are valid.
/// - `ValidateOptionsResult.fail`    – one or more rules were violated.
/// - `ValidateOptionsResult.skip`    – this validator does not apply to the
///   options name being validated.
///
/// Results are aggregated by `OptionsFactory` across all registered
/// validators; failure messages are surfaced together in
/// `OptionsValidationException`.
final class ValidateOptionsResult {
  /// Creates a result directly.
  ///
  /// Prefer the named constructors `success`, `fail`, and `skip` for
  /// readability.
  const ValidateOptionsResult._({
    required this.succeeded,
    required this.skipped,
    this.failures = const [],
  });

  // ---------------------------------------------------------------------------
  // Named constructors
  // ---------------------------------------------------------------------------

  /// Creates a result indicating that the options passed validation.
  factory ValidateOptionsResult.success() => const ValidateOptionsResult._(
        succeeded: true,
        skipped: false,
      );

  /// Creates a result indicating that validation failed with the given
  /// [message].
  ///
  /// [message] should be human-readable and include the options name and the
  /// property that failed, e.g.:
  /// `'DatabaseOptions[primary]: host must not be empty.'`
  factory ValidateOptionsResult.fail(String message) => ValidateOptionsResult._(
        succeeded: false,
        skipped: false,
        failures: [message],
      );

  /// Creates a result indicating that validation failed with multiple
  /// [messages].
  ///
  /// Prefer this over returning multiple `fail` results when a single
  /// validator can produce several distinct errors.
  factory ValidateOptionsResult.failMany(List<String> messages) {
    if (messages.isEmpty) {
      throw ArgumentError.value(
        messages,
        'messages',
        'At least one failure message is required.',
      );
    }
    return ValidateOptionsResult._(
      succeeded: false,
      skipped: false,
      failures: List.unmodifiable(messages),
    );
  }

  /// Creates a result indicating that this validator does not apply to the
  /// options name under evaluation (it will be silently ignored).
  factory ValidateOptionsResult.skip() => const ValidateOptionsResult._(
        succeeded: false,
        skipped: true,
      );

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  /// Whether the validation passed.
  final bool succeeded;

  /// Whether this validator chose to skip evaluation for the current name.
  final bool skipped;

  /// The list of human-readable failure messages.
  ///
  /// Empty when [succeeded] or [skipped] is `true`.
  final List<String> failures;

  /// Whether this result represents a failure (not succeeded and not skipped).
  bool get failed => !succeeded && !skipped;

  @override
  String toString() {
    if (succeeded) return 'ValidateOptionsResult.success';
    if (skipped) return 'ValidateOptionsResult.skip';
    return 'ValidateOptionsResult.fail(${failures.join('; ')})';
  }
}
