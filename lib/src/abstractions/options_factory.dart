/// Creates instances of [T] and applies the full configuration pipeline.
///
/// Analogous to `IOptionsFactory<T>` from Microsoft.Extensions.Options.
///
/// Responsibilities:
/// 1. Instantiate a fresh [T] using the registered factory function.
/// 2. Apply all `ConfigureOptions` registrations (filtered by name).
/// 3. Apply all `PostConfigureOptions` registrations.
/// 4. Run all `ValidateOptions` registrations and collect failures.
/// 5. Throw `OptionsValidationException` if any validation fails.
///
/// This interface is consumed internally by caches and managers; you rarely
/// need to interact with it directly.
abstract interface class OptionsFactory<T extends Object> {
  /// Creates and fully configures a new [T] instance for the given [name].
  ///
  /// Throws `OptionsValidationException` when one or more validators report
  /// failure for the produced instance.
  T create(String name);
}
