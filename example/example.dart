// Examples use print for observable output; this is intentional in example code.
// ignore_for_file: avoid_print
import 'package:davianspace_options/davianspace_options.dart';

// ---------------------------------------------------------------------------
// Domain models
// ---------------------------------------------------------------------------

/// Represents database connection settings for a single connection target.
class DatabaseOptions {
  String host = 'localhost';
  int port = 5432;
  String database = 'app';
  Duration connectTimeout = const Duration(seconds: 30);
  int maxPoolSize = 10;
  bool enableSsl = false;

  String get connectionString =>
      '${enableSsl ? 'postgresql+ssl' : 'postgresql'}://$host:$port/$database'
      '?connect_timeout=${connectTimeout.inSeconds}'
      '&pool_size=$maxPoolSize';
}

/// Represents feature-flag settings that may change at runtime.
class FeatureFlags {
  bool darkMode = false;
  bool betaSearchEnabled = false;
  String rolloutStage = 'stable'; // stable | beta | canary
}

/// Represents API gateway configuration used by outbound HTTP clients.
class ApiGatewayOptions {
  String baseUrl = '';
  Duration requestTimeout = const Duration(seconds: 10);
  int maxRetries = 3;
  String apiKey = '';
}

// ---------------------------------------------------------------------------
// Example 1 — Singleton options (Options<T>)
//
// A single, permanently-cached configuration instance shared for the
// lifetime of the application. Suitable for immutable startup config.
// ---------------------------------------------------------------------------

void exampleSingletonOptions() {
  print('── Example 1: Singleton options ─────────────────────────────────');

  final factory = OptionsFactoryImpl<DatabaseOptions>(
    instanceFactory: DatabaseOptions.new,
    configureOptions: [
      ConfigureNamedOptions(
        name: null, // applies to every named instance
        configure: (opts) {
          opts.host = 'db.prod.internal';
          opts.port = 5432;
          opts.database = 'orders';
          opts.enableSsl = true;
          opts.maxPoolSize = 25;
        },
      ),
    ],
    postConfigureOptions: [
      // Post-configure runs after all configure actions and is a good place
      // for cross-cutting defaults or environment-specific overrides.
      PostConfigureNamedOptions(
        name: null,
        postConfigure: (opts) {
          if (opts.maxPoolSize > 50) opts.maxPoolSize = 50; // enforce cap
        },
      ),
    ],
    validators: [
      DelegateValidateOptions(
        name: null,
        validate: (name, opts) {
          final errors = <String>[];
          if (opts.host.isEmpty) errors.add('host must not be empty');
          if (opts.database.isEmpty) errors.add('database must not be empty');
          if (opts.port < 1 || opts.port > 65535) {
            errors.add('port must be in range 1–65535');
          }
          if (opts.maxPoolSize < 1) {
            errors.add('maxPoolSize must be at least 1');
          }
          return errors.isEmpty
              ? ValidateOptionsResult.success()
              : ValidateOptionsResult.failMany(errors);
        },
      ),
    ],
  );

  // value is constructed once on first access and cached permanently.
  final options = OptionsManager<DatabaseOptions>(factory: factory);
  final db = options.value;
  print('  Connection string : ${db.connectionString}');
  print('  Pool size         : ${db.maxPoolSize}');
  print('  SSL enabled       : ${db.enableSsl}');
}

// ---------------------------------------------------------------------------
// Example 2 — Named options (OptionsSnapshot<T>)
//
// Separate configuration branches per logical name. Common for multi-region
// databases, per-tenant configs, or primary/replica pools.
// ---------------------------------------------------------------------------

void exampleNamedOptions() {
  print('\n── Example 2: Named options (primary / replica pattern) ──────────');

  final factory = OptionsFactoryImpl<DatabaseOptions>(
    instanceFactory: DatabaseOptions.new,
    configureOptions: [
      // Shared defaults applied first (name: null → all instances).
      ConfigureNamedOptions(
        name: null,
        configure: (opts) {
          opts.database = 'orders';
          opts.enableSsl = true;
        },
      ),
      // Primary: high-pool read/write target.
      ConfigureNamedOptions(
        name: 'primary',
        configure: (opts) {
          opts.host = 'primary.db.prod.internal';
          opts.port = 5432;
          opts.maxPoolSize = 20;
        },
      ),
      // Replica: read-only target with a deeper pool for read-heavy workloads.
      ConfigureNamedOptions(
        name: 'replica',
        configure: (opts) {
          opts.host = 'replica.db.prod.internal';
          opts.port = 5433;
          opts.maxPoolSize = 40;
        },
      ),
    ],
  );

  // OptionsManager acts as a scoped snapshot when a new instance is created
  // per scope (e.g. per HTTP request).  Within one scope the same named
  // instance is returned on repeated calls to get().
  final snapshot = OptionsManager<DatabaseOptions>(factory: factory);
  final primary = snapshot.get('primary');
  final replica = snapshot.get('replica');

  print('  Primary  → ${primary.connectionString}');
  print('  Replica  → ${replica.connectionString}');
}

// ---------------------------------------------------------------------------
// Example 3 — Validation pipeline
//
// Validators run after every configure/postConfigure step. All failures are
// aggregated and raised together, giving operators the full picture at once.
// ---------------------------------------------------------------------------

void exampleValidationPipeline() {
  print('\n── Example 3: Validation pipeline ───────────────────────────────');

  final factory = OptionsFactoryImpl<ApiGatewayOptions>(
    instanceFactory: ApiGatewayOptions.new,
    configureOptions: [
      ConfigureNamedOptions(
        name: null,
        configure: (opts) {
          // Simulate loading from environment variables.
          opts.baseUrl = const String.fromEnvironment('API_BASE_URL');
          opts.apiKey = const String.fromEnvironment('API_KEY');
          opts.maxRetries = 3;
          opts.requestTimeout = const Duration(seconds: 15);
        },
      ),
    ],
    validators: [
      DelegateValidateOptions(
        name: null,
        validate: (name, opts) {
          final errors = <String>[];
          if (opts.baseUrl.isEmpty) {
            errors.add('baseUrl is required (set API_BASE_URL env var)');
          }
          if (opts.apiKey.isEmpty) {
            errors.add('apiKey is required (set API_KEY env var)');
          }
          if (opts.maxRetries < 0 || opts.maxRetries > 10) {
            errors.add('maxRetries must be between 0 and 10');
          }
          return errors.isEmpty
              ? ValidateOptionsResult.success()
              : ValidateOptionsResult.failMany(errors);
        },
      ),
    ],
  );

  try {
    factory.create(Options.defaultName);
    print('  ApiGatewayOptions validated successfully.');
  } on OptionsValidationException catch (e) {
    // In a real app, surface these at startup so misconfiguration is
    // caught before the application accepts traffic.
    print('  Configuration is invalid — refusing to start:');
    for (final failure in e.failures) {
      print('    • $failure');
    }
  }
}

// ---------------------------------------------------------------------------
// Example 4 — Fluent builder with multiple configure layers
//
// OptionsBuilder composes configure → postConfigure → validate in one place,
// producing the lists passed to OptionsFactoryImpl.
// ---------------------------------------------------------------------------

void exampleFluentBuilder() {
  print('\n── Example 4: Fluent builder with layered configuration ──────────');

  final builder = OptionsBuilder<FeatureFlags>(
    factory: FeatureFlags.new,
  )
      // Layer 1 — apply defaults from remote config (simulated).
      .configure((opts) {
    opts.rolloutStage = 'stable';
    opts.darkMode = true;
  })
      // Layer 2 — override for specific named instance 'beta-cohort'.
      .configureNamed('beta-cohort', (opts) {
    opts.rolloutStage = 'beta';
    opts.betaSearchEnabled = true;
  })
      // PostConfigure — enforce invariants after all configure layers.
      .postConfigure((opts) {
    // Beta search must only be on in non-stable stages.
    if (opts.rolloutStage == 'stable') {
      opts.betaSearchEnabled = false;
    }
  }).validate((name, opts) {
    const allowed = {'stable', 'beta', 'canary'};
    return allowed.contains(opts.rolloutStage)
        ? ValidateOptionsResult.success()
        : ValidateOptionsResult.fail(
            '$name: rolloutStage "${opts.rolloutStage}" is not a valid stage.',
          );
  });

  final factory = OptionsFactoryImpl<FeatureFlags>(
    instanceFactory: builder.factory,
    configureOptions: builder.configureActions,
    postConfigureOptions: builder.postConfigureActions,
    validators: builder.validators,
  );

  final defaultInstance = factory.create(Options.defaultName);
  final betaCohort = factory.create('beta-cohort');

  print('  [default]     stage=${defaultInstance.rolloutStage}'
      '  darkMode=${defaultInstance.darkMode}'
      '  betaSearch=${defaultInstance.betaSearchEnabled}');
  print('  [beta-cohort] stage=${betaCohort.rolloutStage}'
      '  darkMode=${betaCohort.darkMode}'
      '  betaSearch=${betaCohort.betaSearchEnabled}');
}

// ---------------------------------------------------------------------------
// Example 5 — Live change notifications (OptionsMonitor<T>)
//
// OptionsMonitor keeps the current value live and fires listeners when the
// underlying configuration source signals a change.  Combine with an
// OptionsChangeNotifier to drive reloads from any source (file watcher,
// remote config poll, internal event bus, etc.).
// ---------------------------------------------------------------------------

void exampleOptionsMonitor() {
  print('\n── Example 5: Live options monitor ──────────────────────────────');

  // The notifier is the bridge between an external change source and the
  // monitor.  In production this would be triggered by a file watcher,
  // a remote configuration service, or an admin API endpoint.
  final notifier = OptionsChangeNotifier();

  // Simulates a mutable config source (e.g. a remote key-value store).
  var remoteRolloutStage = 'stable';

  final factory = OptionsFactoryImpl<FeatureFlags>(
    instanceFactory: FeatureFlags.new,
    configureOptions: [
      ConfigureNamedOptions(
        name: null,
        configure: (opts) => opts.rolloutStage = remoteRolloutStage,
      ),
    ],
  );

  final monitor = OptionsMonitorImpl<FeatureFlags>(
    factory: factory,
    notifier: notifier,
  );

  // Register a listener — dispose the returned registration when the
  // subscriber is torn down (e.g. widget dispose, service shutdown).
  final registration = monitor.onChange((flags, name) {
    print('  [onChange] "$name" reloaded → stage=${flags.rolloutStage}');
  });

  print('  Initial stage : ${monitor.currentValue.rolloutStage}');

  // Simulate a remote config push: update the source and signal the notifier.
  remoteRolloutStage = 'canary';
  notifier.notifyChange(Options.defaultName);

  print('  After reload  : ${monitor.currentValue.rolloutStage}');

  // Always dispose listeners and the monitor when done to prevent leaks.
  registration.dispose();
  monitor.dispose();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  exampleSingletonOptions();
  exampleNamedOptions();
  exampleValidationPipeline();
  exampleFluentBuilder();
  exampleOptionsMonitor();
}
