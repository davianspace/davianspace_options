# davianspace_options

[![pub.dev](https://img.shields.io/pub/v/davianspace_options?label=pub.dev)](https://pub.dev/packages/davianspace_options)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Enterprise-grade **Options pattern** for Dart and Flutter — conceptually
equivalent to **Microsoft.Extensions.Options** but expressed idiomatically in
Dart, with no reflection, no mirrors, and zero external dependencies.

---

## Features

| Concept | Dart equivalent | Description |
|---|---|---|
| `IOptions<T>` | `Options<T>` | Singleton-cached access |
| `IOptionsSnapshot<T>` | `OptionsSnapshot<T>` | Scoped / per-scope fresh snapshot |
| `IOptionsMonitor<T>` | `OptionsMonitor<T>` | Live access + change notifications |
| `IOptionsFactory<T>` | `OptionsFactory<T>` | Factory pipeline with validation |
| `IOptionsMonitorCache<T>` | `OptionsMonitorCache<T>` | Per-name instance cache |
| `IConfigureOptions<T>` | `ConfigureOptions<T>` | Configure registrations |
| `IPostConfigureOptions<T>` | `PostConfigureOptions<T>` | Post-configure registrations |
| `IValidateOptions<T>` | `ValidateOptions<T>` | Validation registrations |
| Named options | `OptionsBuilder.configureNamed()` | Per-name configuration branches |
| `IChangeToken` | `ChangeToken` | Change propagation primitives |

---

## Installation

```yaml
dependencies:
  davianspace_options: ^1.0.0
```

---

## Quick start

### 1 — Simple singleton options (`Options<T>`)

```dart
import 'package:davianspace_options/davianspace_options.dart';

class DatabaseOptions {
  String host = 'localhost';
  int    port = 5432;
}

void main() {
  final factory = OptionsFactoryImpl<DatabaseOptions>(
    instanceFactory: DatabaseOptions.new,
    configureOptions: [
      ConfigureNamedOptions(
        name: null, // applies to every name
        configure: (opts) {
          opts.host = 'db.example.com';
          opts.port = 5432;
        },
      ),
    ],
  );

  final options = OptionsManager<DatabaseOptions>(factory: factory);

  // Lazily created once, cached forever.
  final db = options.value;
  print(db.host); // db.example.com

  // Same physical instance on repeated access.
  assert(identical(options.value, db));
}
```

---

### 2 — Named options

```dart
final options = OptionsManager<DatabaseOptions>(factory: factory);

final primary = options.get('primary');
final replica  = options.get('replica');

// Different instances, independently configured.
```

---

### 3 — Validation

```dart
final factory = OptionsFactoryImpl<DatabaseOptions>(
  instanceFactory: DatabaseOptions.new,
  validators: [
    DelegateValidateOptions(
      name: null,
      validate: (name, opts) {
        if (opts.host.isEmpty) {
          return ValidateOptionsResult.fail('$name: host is required.');
        }
        return ValidateOptionsResult.success();
      },
    ),
  ],
);

try {
  factory.create(Options.defaultName); // throws if host is empty
} on OptionsValidationException catch (e) {
  for (final msg in e.failures) print(msg);
}
```

---

### 4 — Fluent builder

```dart
final builder = OptionsBuilder<DatabaseOptions>(factory: DatabaseOptions.new)
  ..configure((opts) => opts.host = 'db.example.com')
  ..postConfigure((opts) => opts.port = opts.port == 0 ? 5432 : opts.port)
  ..validate(
    (name, opts) => opts.host.isNotEmpty
        ? ValidateOptionsResult.success()
        : ValidateOptionsResult.fail('$name: host required'),
  );

final factory = OptionsFactoryImpl<DatabaseOptions>(
  instanceFactory: builder.factory,
  configureOptions:     builder.configureActions,
  postConfigureOptions: builder.postConfigureActions,
  validators:           builder.validators,
);
```

---

### 5 — Live change notifications (`OptionsMonitor<T>`)

```dart
final notifier = OptionsChangeNotifier();

final monitor = OptionsMonitorImpl<DatabaseOptions>(
  factory:  factory,
  notifier: notifier,
);

final registration = monitor.onChange((opts, name) {
  print('$name changed → host=${opts.host}');
});

// Trigger a reload from your app (file watcher, remote config, etc.):
notifier.notifyChange(Options.defaultName);

// Always dispose when done:
registration.dispose();
monitor.dispose();
```

---

### 6 — Scoped snapshot (`OptionsSnapshot<T>`)

Create one `OptionsManager` per logical scope (request, unit-of-work, test) to
get a fresh snapshot that remains stable within that scope:

```dart
void handleRequest(OptionsFactory<FeatureFlags> factory) {
  // New manager = new scope; instances are created fresh from the factory.
  final snapshot = OptionsManager<FeatureFlags>(factory: factory);

  final flags  = snapshot.value;         // cached within this scope
  final beta   = snapshot.get('beta');   // independent named snapshot

  // ... use flags ...
}
```

---

### 7 — Flutter integration hint

```dart
// In your service locator / DI setup:
final getIt = GetIt.instance;

getIt.registerSingleton(
  OptionsManager<ThemeOptions>(factory: themeFactory),
);

// In a widget:
final theme = getIt<OptionsManager<ThemeOptions>>().value;
```

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│  Application layer                                             │
│  OptionsManager  •  OptionsMonitorImpl  •  OptionsBuilder      │
├────────────────────────────────────────────────────────────────┤
│  Factory pipeline                                              │
│  OptionsFactoryImpl                                            │
│    1. instantiate  →  2. configure  →  3. postConfigure        │
│    4. validate  →  (throws OptionsValidationException)         │
├────────────────────────────────────────────────────────────────┤
│  Cache layer                                                   │
│  OptionsMonitorCacheImpl  (per-name Map, O(1) lookup)          │
├────────────────────────────────────────────────────────────────┤
│  Change tracking                                               │
│  ManualChangeToken  •  CompositeChangeToken  •                 │
│  NeverChangeToken   •  OptionsChangeNotifier                   │
└────────────────────────────────────────────────────────────────┘
```

---

## Migration notes from Microsoft.Extensions.Options

| .NET API | Dart equivalent |
|---|---|
| `services.AddOptions<T>()` | `OptionsBuilder<T>(factory: T.new)` |
| `.Configure<T>(action)` | `builder.configure(action)` |
| `.Configure<T>(name, action)` | `builder.configureNamed(name, action)` |
| `.PostConfigure<T>(action)` | `builder.postConfigure(action)` |
| `.ValidateDataAnnotations()` | `builder.validate(closureValidator)` |
| `IOptions<T>.Value` | `OptionsManager<T>.value` |
| `IOptionsSnapshot<T>.Get(name)` | `OptionsManager<T>.get(name)` |
| `IOptionsMonitor<T>.CurrentValue` | `OptionsMonitorImpl<T>.currentValue` |
| `IOptionsMonitor<T>.OnChange(cb)` | `monitor.onChange(cb)` → disposable |
| `IOptionsMonitorCache<T>.Clear()` | `OptionsMonitorCacheImpl<T>.clear()` |
| `IChangeToken` | `ChangeToken` |
| `CancellationTokenSource` | `ManualChangeToken` |

Key differences:
- **No reflection or code generation** – register a factory closure instead of
  relying on `Activator.CreateInstance`.
- **No DI container coupling** – the library is container-agnostic; wire it
  into GetIt, Riverpod, or any other solution.
- **Disposal is explicit** – call `monitor.dispose()` and
  `registration.dispose()` rather than relying on `IDisposable` from a DI
  container lifetime scope.
- **Scoped snapshot via new instance** – create a new `OptionsManager` per
  scope instead of registering with `Scoped` lifetime.

---

## Performance

- O(1) retrieval after first creation (hash-map backed cache).
- No reflection, no `dart:mirrors`.
- Factory closures — zero-cost compared to activator pattern.
- Listener list is a plain `List<Function>`; add/remove are O(n) but lists
  are tiny in practice.

---

## License

MIT — see [LICENSE](LICENSE).
