# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.3] — 2026-02-25

### Changed

- **`lints` dev-dependency bumped** — updated `lints` from `^3.0.0` to `^6.0.0`
  to eliminate `sort_pub_dependencies` and other new lint recommendations.

---

## [1.0.0] — 2026-02-25

### Added

- `Options<T>` – singleton-cached access abstraction.
- `OptionsSnapshot<T>` – scoped/per-request snapshot abstraction.
- `OptionsMonitor<T>` – live access with change-notification abstraction.
- `OptionsFactory<T>` – factory pipeline abstraction.
- `OptionsMonitorCache<T>` – per-name instance cache abstraction.
- `ConfigureOptions<T>` – configure registration abstraction.
- `PostConfigureOptions<T>` – post-configure registration abstraction.
- `ValidateOptions<T>` – validate registration abstraction.
- `OptionsManager<T>` – default implementation of `Options<T>` and `OptionsSnapshot<T>`.
- `OptionsFactoryImpl<T>` – default implementation of `OptionsFactory<T>`.
- `OptionsMonitorCacheImpl<T>` – default implementation of `OptionsMonitorCache<T>`.
- `OptionsMonitorImpl<T>` – default implementation of `OptionsMonitor<T>` with
  change tracking and listener management.
- `ValidateOptionsResult` – success / fail / skip discriminated value.
- `OptionsValidationException` – aggregated validation failure.
- `ChangeToken` / `ManualChangeToken` / `CompositeChangeToken` / `NeverChangeToken`.
- `OptionsChangeNotifier` – in-process per-name token manager.
- `OptionsBuilder<T>` – fluent builder for configure/postConfigure/validate pipelines.
- `ConfigureNamedOptions<T>` – closure-based `ConfigureOptions<T>`.
- `PostConfigureNamedOptions<T>` – closure-based `PostConfigureOptions<T>`.
- `DelegateValidateOptions<T>` – closure-based `ValidateOptions<T>`.
- Full unit test suite covering all public APIs.
- Comprehensive API documentation (dartdoc).
- README with quick-start, migration notes, and architecture diagram.
