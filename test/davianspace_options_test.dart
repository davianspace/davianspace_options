import 'package:davianspace_options/davianspace_options.dart';
import 'package:test/test.dart';

// =============================================================================
// Fixtures
// =============================================================================

class AppOptions {
  String name = '';
  int timeout = 0;
  bool enabled = false;
}

OptionsFactoryImpl<AppOptions> _buildFactory({
  List<ConfigureOptions<AppOptions>> configure = const [],
  List<PostConfigureOptions<AppOptions>> postConfigure = const [],
  List<ValidateOptions<AppOptions>> validators = const [],
}) =>
    OptionsFactoryImpl<AppOptions>(
      instanceFactory: AppOptions.new,
      configureOptions: configure,
      postConfigureOptions: postConfigure,
      validators: validators,
    );

// =============================================================================
// 1. OptionsManager (Options<T> + OptionsSnapshot<T>)
// =============================================================================

void main() {
  group('OptionsManager – Options<T>', () {
    test('returns the default instance via .value', () {
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(
            name: null,
            configure: (o) => o.name = 'default',
          ),
        ],
      );
      final manager = OptionsManager<AppOptions>(factory: factory);
      expect(manager.value.name, 'default');
    });

    test('caches the same instance on repeated .value calls', () {
      final factory = _buildFactory();
      final manager = OptionsManager<AppOptions>(factory: factory);
      expect(identical(manager.value, manager.value), isTrue);
    });

    test('.get(defaultName) is identical to .value', () {
      final factory = _buildFactory();
      final manager = OptionsManager<AppOptions>(factory: factory);
      expect(
        identical(manager.value, manager.get(Options.defaultName)),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('OptionsManager – OptionsSnapshot<T>', () {
    test('returns distinct instances for distinct names', () {
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(
            name: 'a',
            configure: (o) => o.name = 'instance-a',
          ),
          ConfigureNamedOptions(
            name: 'b',
            configure: (o) => o.name = 'instance-b',
          ),
        ],
      );
      final snapshot = OptionsManager<AppOptions>(factory: factory);
      final a = snapshot.get('a');
      final b = snapshot.get('b');
      expect(a.name, 'instance-a');
      expect(b.name, 'instance-b');
      expect(identical(a, b), isFalse);
    });

    test('returns the same cached instance for the same name within a scope',
        () {
      final factory = _buildFactory();
      final snapshot = OptionsManager<AppOptions>(factory: factory);
      expect(identical(snapshot.get('x'), snapshot.get('x')), isTrue);
    });

    test('different scope (new OptionsManager) recreates the instance', () {
      final factory = _buildFactory();
      final scope1 = OptionsManager<AppOptions>(factory: factory);
      final scope2 = OptionsManager<AppOptions>(factory: factory);
      expect(identical(scope1.value, scope2.value), isFalse);
    });
  });

  // ---------------------------------------------------------------------------

  // ==========================================================================
  // 2. OptionsFactory pipeline
  // ==========================================================================

  group('OptionsFactoryImpl – pipeline ordering', () {
    test('configure runs before postConfigure', () {
      final order = <String>[];
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(
            name: null,
            configure: (_) => order.add('configure'),
          ),
        ],
        postConfigure: [
          PostConfigureNamedOptions(
            name: null,
            postConfigure: (_) => order.add('postConfigure'),
          ),
        ],
      );
      factory.create(Options.defaultName);
      expect(order, ['configure', 'postConfigure']);
    });

    test('multiple configure registrations run in registration order', () {
      final order = <int>[];
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(name: null, configure: (_) => order.add(1)),
          ConfigureNamedOptions(name: null, configure: (_) => order.add(2)),
          ConfigureNamedOptions(name: null, configure: (_) => order.add(3)),
        ],
      );
      factory.create(Options.defaultName);
      expect(order, [1, 2, 3]);
    });

    test('named configure applies only to matching name', () {
      final factory = OptionsFactoryImpl<AppOptions>(
        instanceFactory: AppOptions.new,
        configureOptions: [
          ConfigureNamedOptions(
            name: 'target',
            configure: (o) => o.name = 'set-by-configure',
          ),
        ],
      );
      final target = factory.create('target');
      final other = factory.create('other');
      expect(target.name, 'set-by-configure');
      expect(other.name, ''); // default constructor value
    });

    test('null-name configure applies to all names', () {
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(
            name: null,
            configure: (o) => o.timeout = 99,
          ),
        ],
      );
      expect(factory.create('a').timeout, 99);
      expect(factory.create('b').timeout, 99);
      expect(factory.create(Options.defaultName).timeout, 99);
    });

    test('postConfigure overrides configure mutation', () {
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(name: null, configure: (o) => o.timeout = 10),
        ],
        postConfigure: [
          PostConfigureNamedOptions(
            name: null,
            postConfigure: (o) => o.timeout = 999,
          ),
        ],
      );
      expect(factory.create(Options.defaultName).timeout, 999);
    });

    test('creates a fresh instance each call (no internal caching)', () {
      final factory = _buildFactory();
      final a = factory.create(Options.defaultName);
      final b = factory.create(Options.defaultName);
      expect(identical(a, b), isFalse);
    });
  });

  // ==========================================================================
  // 3. Validation
  // ==========================================================================

  group('ValidateOptionsResult', () {
    test('success result', () {
      final r = ValidateOptionsResult.success();
      expect(r.succeeded, isTrue);
      expect(r.skipped, isFalse);
      expect(r.failed, isFalse);
      expect(r.failures, isEmpty);
    });

    test('fail result with single message', () {
      final r = ValidateOptionsResult.fail('bad value');
      expect(r.succeeded, isFalse);
      expect(r.skipped, isFalse);
      expect(r.failed, isTrue);
      expect(r.failures, ['bad value']);
    });

    test('failMany result', () {
      final r = ValidateOptionsResult.failMany(['e1', 'e2']);
      expect(r.failures.length, 2);
      expect(r.failed, isTrue);
    });

    test('failMany throws on empty list', () {
      expect(() => ValidateOptionsResult.failMany([]), throwsArgumentError);
    });

    test('skip result', () {
      final r = ValidateOptionsResult.skip();
      expect(r.succeeded, isFalse);
      expect(r.skipped, isTrue);
      expect(r.failed, isFalse);
    });
  });

  group('OptionsFactoryImpl – validation', () {
    test('throws OptionsValidationException when validator fails', () {
      final factory = _buildFactory(
        validators: [
          DelegateValidateOptions(
            name: null,
            validate: (_, o) => o.name.isEmpty
                ? ValidateOptionsResult.fail('name is required')
                : ValidateOptionsResult.success(),
          ),
        ],
      );
      expect(
        () => factory.create(Options.defaultName),
        throwsA(isA<OptionsValidationException>()),
      );
    });

    test('aggregates failures from multiple validators', () {
      final factory = _buildFactory(
        validators: [
          DelegateValidateOptions(
            name: null,
            validate: (_, __) => ValidateOptionsResult.fail('error-A'),
          ),
          DelegateValidateOptions(
            name: null,
            validate: (_, __) => ValidateOptionsResult.fail('error-B'),
          ),
        ],
      );
      try {
        factory.create(Options.defaultName);
        fail('Expected OptionsValidationException');
      } on OptionsValidationException catch (e) {
        expect(e.failures.length, 2);
        expect(e.failures, containsAll(['error-A', 'error-B']));
        expect(e.optionsType, AppOptions);
      }
    });

    test('skipped validators are ignored', () {
      final factory = _buildFactory(
        validators: [
          DelegateValidateOptions(
            name: null,
            validate: (_, __) => ValidateOptionsResult.skip(),
          ),
        ],
      );
      expect(() => factory.create(Options.defaultName), returnsNormally);
    });

    test('validator scoped to a name does not run for other names', () {
      final factory = _buildFactory(
        validators: [
          DelegateValidateOptions(
            name: 'dangerous',
            validate: (_, __) => ValidateOptionsResult.fail('blocked'),
          ),
        ],
      );
      // 'safe' should not trigger the validator
      expect(() => factory.create('safe'), returnsNormally);
      // 'dangerous' should
      expect(
        () => factory.create('dangerous'),
        throwsA(isA<OptionsValidationException>()),
      );
    });

    test('succeeds when all validators pass', () {
      final factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(name: null, configure: (o) => o.name = 'ok'),
        ],
        validators: [
          DelegateValidateOptions(
            name: null,
            validate: (_, o) => o.name.isNotEmpty
                ? ValidateOptionsResult.success()
                : ValidateOptionsResult.fail('name required'),
          ),
        ],
      );
      expect(
        () => factory.create(Options.defaultName),
        returnsNormally,
      );
    });
  });

  group('OptionsValidationException', () {
    test('toString contains type, name, and failures', () {
      final e = OptionsValidationException(
        optionsType: AppOptions,
        optionsName: 'primary',
        failures: ['f1', 'f2'],
      );
      final s = e.toString();
      expect(s, contains('AppOptions'));
      expect(s, contains('primary'));
      expect(s, contains('f1'));
      expect(s, contains('f2'));
    });

    test('empty optionsName is allowed (default name)', () {
      final e = OptionsValidationException(
        optionsType: AppOptions,
        optionsName: Options.defaultName,
        failures: ['oops'],
      );
      expect(e.optionsName, isEmpty);
      expect(e.toString(), isNotEmpty);
    });
  });

  // ==========================================================================
  // 4. ManualChangeToken
  // ==========================================================================

  group('ManualChangeToken', () {
    test('starts as not changed', () {
      final token = ManualChangeToken();
      expect(token.hasChanged, isFalse);
    });

    test('notifyChanged fires all registered callbacks', () {
      final token = ManualChangeToken();
      final log = <int>[];
      token.registerCallback(() => log.add(1));
      token.registerCallback(() => log.add(2));
      token.notifyChanged();
      expect(log, [1, 2]);
    });

    test('hasChanged is true after notifyChanged', () {
      final token = ManualChangeToken();
      token.notifyChanged();
      expect(token.hasChanged, isTrue);
    });

    test('callbacks are not called twice if notifyChanged is called twice', () {
      final token = ManualChangeToken();
      int count = 0;
      token.registerCallback(() => count++);
      token.notifyChanged();
      token.notifyChanged(); // no-op
      expect(count, 1);
    });

    test('disposed registration is not called', () {
      final token = ManualChangeToken();
      int count = 0;
      final reg = token.registerCallback(() => count++);
      reg.dispose();
      token.notifyChanged();
      expect(count, 0);
    });

    test('late registration after change fires via microtask', () async {
      final token = ManualChangeToken();
      token.notifyChanged();
      int count = 0;
      token.registerCallback(() => count++);
      await Future.microtask(() {}); // let microtask queue flush
      expect(count, 1);
    });
  });

  // ==========================================================================
  // 5. CompositeChangeToken
  // ==========================================================================

  group('CompositeChangeToken', () {
    test('hasChanged is false when no child has changed', () {
      final t1 = ManualChangeToken();
      final t2 = ManualChangeToken();
      final composite = CompositeChangeToken([t1, t2]);
      expect(composite.hasChanged, isFalse);
    });

    test('hasChanged is true when any child fires', () {
      final t1 = ManualChangeToken();
      final t2 = ManualChangeToken();
      final composite = CompositeChangeToken([t1, t2]);
      t2.notifyChanged();
      expect(composite.hasChanged, isTrue);
    });

    test('callback fires when any child token fires', () {
      final t1 = ManualChangeToken();
      final t2 = ManualChangeToken();
      final composite = CompositeChangeToken([t1, t2]);
      int count = 0;
      composite.registerCallback(() => count++);
      t1.notifyChanged();
      expect(count, 1);
    });

    test('callback fires only once even if multiple children fire', () {
      final t1 = ManualChangeToken();
      final t2 = ManualChangeToken();
      final composite = CompositeChangeToken([t1, t2]);
      int count = 0;
      composite.registerCallback(() => count++);
      t1.notifyChanged();
      t2.notifyChanged();
      expect(count, 1); // once is enough – token is single-use
    });

    test('throws on empty token list', () {
      expect(() => CompositeChangeToken([]), throwsA(isA<AssertionError>()));
    });
  });

  // ==========================================================================
  // 6. NeverChangeToken
  // ==========================================================================

  group('NeverChangeToken', () {
    test('hasChanged is always false', () {
      expect(NeverChangeToken.instance.hasChanged, isFalse);
    });

    test('registerCallback returns no-op registration', () {
      int count = 0;
      final reg = NeverChangeToken.instance.registerCallback(() => count++);
      reg.dispose(); // should not throw
      expect(count, 0);
    });
  });

  // ==========================================================================
  // 7. OptionsChangeNotifier
  // ==========================================================================

  group('OptionsChangeNotifier', () {
    test('getChangeToken returns a stable token until notifyChange is called',
        () {
      final notifier = OptionsChangeNotifier();
      final t1 = notifier.getChangeToken('x');
      final t2 = notifier.getChangeToken('x');
      expect(identical(t1, t2), isTrue);
    });

    test('notifyChange fires the current token callbacks', () {
      final notifier = OptionsChangeNotifier();
      int count = 0;
      notifier.getChangeToken('x').registerCallback(() => count++);
      notifier.notifyChange('x');
      expect(count, 1);
    });

    test('after notifyChange a new token is served', () {
      final notifier = OptionsChangeNotifier();
      final before = notifier.getChangeToken('x');
      notifier.notifyChange('x');
      final after = notifier.getChangeToken('x');
      expect(identical(before, after), isFalse);
      expect(before.hasChanged, isTrue);
      expect(after.hasChanged, isFalse);
    });

    test('notifyAll fires tokens for all known names', () {
      final notifier = OptionsChangeNotifier();
      int countA = 0, countB = 0;
      notifier.getChangeToken('a').registerCallback(() => countA++);
      notifier.getChangeToken('b').registerCallback(() => countB++);
      notifier.notifyAll();
      expect(countA, 1);
      expect(countB, 1);
    });

    test('unknown name notify is a no-op', () {
      final notifier = OptionsChangeNotifier();
      expect(() => notifier.notifyChange('unknown'), returnsNormally);
    });
  });

  // ==========================================================================
  // 8. OptionsMonitorImpl
  // ==========================================================================

  group('OptionsMonitorImpl', () {
    late OptionsChangeNotifier notifier;
    late OptionsFactoryImpl<AppOptions> factory;
    late OptionsMonitorImpl<AppOptions> monitor;

    setUp(() {
      notifier = OptionsChangeNotifier();
      factory = _buildFactory(
        configure: [
          ConfigureNamedOptions(
            name: null,
            configure: (o) => o.name = 'initial',
          ),
        ],
      );
      monitor = OptionsMonitorImpl<AppOptions>(
        factory: factory,
        notifier: notifier,
      );
    });

    tearDown(() => monitor.dispose());

    test('currentValue returns the default instance', () {
      expect(monitor.currentValue.name, 'initial');
    });

    test('get returns named instance', () {
      final factory2 = OptionsFactoryImpl<AppOptions>(
        instanceFactory: AppOptions.new,
        configureOptions: [
          ConfigureNamedOptions(
            name: 'secondary',
            configure: (o) => o.name = 'sec',
          ),
        ],
      );
      final mon2 = OptionsMonitorImpl<AppOptions>(
        factory: factory2,
        notifier: notifier,
      );
      expect(mon2.get('secondary').name, 'sec');
      mon2.dispose();
    });

    test('onChange listener is called on reload', () {
      final events = <String>[];
      monitor.onChange((opts, name) => events.add('$name:${opts.name}'));

      notifier.notifyChange(Options.defaultName);
      expect(events, [':initial']);
    });

    test('disposed onChange registration is NOT called', () {
      int count = 0;
      final reg = monitor.onChange((_, __) => count++);
      reg.dispose();
      notifier.notifyChange(Options.defaultName);
      expect(count, 0);
    });

    test('cache is invalidated on reload', () {
      var counter = 0;
      final factory2 = OptionsFactoryImpl<AppOptions>(
        instanceFactory: () {
          counter++;
          return AppOptions()..timeout = counter;
        },
      );
      final mon2 = OptionsMonitorImpl<AppOptions>(
        factory: factory2,
        notifier: notifier,
      );

      final v1 = mon2.currentValue;
      notifier.notifyChange(Options.defaultName);
      final v2 = mon2.currentValue;

      expect(identical(v1, v2), isFalse);
      expect(v1.timeout, 1);
      expect(v2.timeout, 2);

      mon2.dispose();
    });

    test('multiple listeners all receive change event', () {
      final log = <String>[];
      monitor.onChange((_, __) => log.add('l1'));
      monitor.onChange((_, __) => log.add('l2'));
      notifier.notifyChange(Options.defaultName);
      expect(log, containsAll(['l1', 'l2']));
    });

    test('disposed monitor throws on get', () {
      monitor.dispose();
      expect(() => monitor.currentValue, throwsStateError);
    });

    test('disposed monitor throws on onChange', () {
      monitor.dispose();
      expect(() => monitor.onChange((_, __) {}), throwsStateError);
    });
  });

  // ==========================================================================
  // 9. OptionsMonitorCacheImpl
  // ==========================================================================

  group('OptionsMonitorCacheImpl', () {
    test('getOrAdd calls factory once for the same name', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      int calls = 0;
      AppOptions make() {
        calls++;
        return AppOptions();
      }

      cache.getOrAdd('a', make);
      cache.getOrAdd('a', make);
      expect(calls, 1);
    });

    test('getOrAdd with different names calls factory for each', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      int calls = 0;
      AppOptions make() {
        calls++;
        return AppOptions();
      }

      cache.getOrAdd('a', make);
      cache.getOrAdd('b', make);
      expect(calls, 2);
    });

    test('tryAdd returns true for new key and false for existing', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      expect(cache.tryAdd('k', AppOptions()), isTrue);
      expect(cache.tryAdd('k', AppOptions()), isFalse);
    });

    test('tryRemove removes entry and subsequent getOrAdd creates fresh', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      final a = cache.getOrAdd('x', AppOptions.new);
      cache.tryRemove('x');
      final b = cache.getOrAdd('x', AppOptions.new);
      expect(identical(a, b), isFalse);
    });

    test('tryRemove returns false for missing key', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      expect(cache.tryRemove('missing'), isFalse);
    });

    test('clear removes all entries', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      cache.getOrAdd('a', AppOptions.new);
      cache.getOrAdd('b', AppOptions.new);
      cache.clear();
      expect(cache.length, 0);
    });
  });

  // ==========================================================================
  // 10. OptionsBuilder
  // ==========================================================================

  group('OptionsBuilder', () {
    test('configure and validate are accessible via getters', () {
      final builder = OptionsBuilder<AppOptions>(factory: AppOptions.new)
        ..configure((o) => o.name = 'built')
        ..validate((_, o) => ValidateOptionsResult.success());

      expect(builder.configureActions.length, 1);
      expect(builder.validators.length, 1);
    });

    test('configureNamed creates a named ConfigureNamedOptions', () {
      final builder = OptionsBuilder<AppOptions>(factory: AppOptions.new)
        ..configureNamed('x', (o) => o.name = 'x-val');

      final action = builder.configureActions.first;
      expect(action.name, 'x');
    });

    test('postConfigure is added to postConfigureActions', () {
      final builder = OptionsBuilder<AppOptions>(factory: AppOptions.new)
        ..postConfigure((_) {});

      expect(builder.postConfigureActions.length, 1);
    });

    test('full pipeline via builder produces correct options', () {
      final builder = OptionsBuilder<AppOptions>(factory: AppOptions.new)
        ..configure((o) => o.timeout = 10)
        ..postConfigure((o) => o.enabled = true)
        ..validate(
          (_, o) => o.timeout > 0
              ? ValidateOptionsResult.success()
              : ValidateOptionsResult.fail('timeout > 0'),
        );

      final factory = OptionsFactoryImpl<AppOptions>(
        instanceFactory: builder.factory,
        configureOptions: builder.configureActions,
        postConfigureOptions: builder.postConfigureActions,
        validators: builder.validators,
      );

      final opts = factory.create(Options.defaultName);
      expect(opts.timeout, 10);
      expect(opts.enabled, isTrue);
    });
  });

  // ==========================================================================
  // 11. Default name constant
  // ==========================================================================

  group('Options.defaultName', () {
    test('is the empty string', () {
      expect(Options.defaultName, '');
    });
  });

  // ==========================================================================
  // 12. Snapshot isolation (different scopes don't share instances)
  // ==========================================================================

  group('Snapshot isolation', () {
    test('two managers produce independent snapshots', () {
      var counter = 0;
      final factory = OptionsFactoryImpl<AppOptions>(
        instanceFactory: () => AppOptions()..timeout = ++counter,
      );

      final s1 = OptionsManager<AppOptions>(factory: factory);
      final s2 = OptionsManager<AppOptions>(factory: factory);

      expect(s1.value.timeout, 1);
      expect(s2.value.timeout, 2);
      expect(identical(s1.value, s2.value), isFalse);
    });
  });

  // ==========================================================================
  // 13. OptionsFactoryExtensions
  // ==========================================================================

  group('OptionsFactoryExtensions', () {
    test('createDefault() delegates to create(defaultName)', () {
      final factory = OptionsFactoryImpl<AppOptions>(
        instanceFactory: AppOptions.new,
        configureOptions: [
          ConfigureNamedOptions(
            name: Options.defaultName,
            configure: (o) => o.name = 'via-default',
          ),
        ],
      );

      final opts = factory.createDefault();
      expect(opts.name, 'via-default');
    });
  });

  // ==========================================================================
  // 14. Concurrent-access simulation (rapid synchronous calls)
  // ==========================================================================

  group('Concurrent-access simulation', () {
    test('cache withstands rapid repeated calls without duplication', () {
      final cache = OptionsMonitorCacheImpl<AppOptions>();
      int createdCount = 0;

      for (int i = 0; i < 1000; i++) {
        cache.getOrAdd('key', () {
          createdCount++;
          return AppOptions();
        });
      }

      // Factory must be called exactly once; Dart's sync model ensures this.
      expect(createdCount, 1);
    });

    test('monitor handles rapid notifyChange cycles', () {
      final notifier = OptionsChangeNotifier();
      var buildCount = 0;

      final factory = OptionsFactoryImpl<AppOptions>(
        instanceFactory: () {
          buildCount++;
          return AppOptions();
        },
      );

      final monitor = OptionsMonitorImpl<AppOptions>(
        factory: factory,
        notifier: notifier,
      );

      // Warm up
      monitor.currentValue;
      final initialBuilds = buildCount;

      // Rapid reload cycle
      for (int i = 0; i < 50; i++) {
        notifier.notifyChange(Options.defaultName);
      }

      // Each notifyChange evicts and recreates, so buildCount must have grown.
      expect(buildCount, greaterThan(initialBuilds));

      monitor.dispose();
    });
  });
}
