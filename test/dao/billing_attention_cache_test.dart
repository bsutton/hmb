import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/billing_attention_cache.dart';
import 'package:hmb/dao/job_billing_readiness_service.dart';

void main() {
  test('concurrent consumers share and reuse a scan', () async {
    var calls = 0;
    final result = Completer<List<JobBillingReadiness>>();
    final cache = BillingAttentionCache(
      load: () {
        calls++;
        return result.future;
      },
      databaseIdentity: () => null,
    );
    addTearDown(cache.dispose);
    final first = cache.refresh();
    final second = cache.refresh();
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(cache.updating, isTrue);
    expect(cache.entries, isNull);
    result.complete([]);
    await first;
    await cache.refresh();
    expect(calls, 1);
    expect(cache.entries, isEmpty);
    expect(cache.updating, isFalse);
  });

  test('a write during a scan triggers a second pass', () async {
    final result = Completer<List<JobBillingReadiness>>();
    var calls = 0;
    final cache = BillingAttentionCache(
      load: () {
        calls++;
        return calls == 1 ? result.future : Future.value([]);
      },
      databaseIdentity: () => null,
    );
    addTearDown(cache.dispose);
    final scan = cache.refresh();
    await Future<void>.delayed(Duration.zero);
    cache.invalidateTable('time_entry');
    result.complete([]);
    await scan;
    expect(calls, 2);
    expect(cache.error, isNull);
  });

  test('failed refresh retains last result and retries', () async {
    var fail = false;
    final cache = BillingAttentionCache(
      load: () async {
        if (fail) {
          throw StateError('offline');
        }
        return [];
      },
      databaseIdentity: () => null,
    );
    addTearDown(cache.dispose);
    await cache.refresh();
    final result = cache.entries;
    fail = true;
    await cache.refresh(force: true);
    expect(identical(cache.entries, result), isTrue);
    expect(cache.error, isNotNull);
    expect(cache.updating, isFalse);
    fail = false;
    await cache.refresh();
    expect(cache.error, isNull);
  });

  test('database replacement discards the previous database result', () async {
    var identity = Object();
    var fail = false;
    final cache = BillingAttentionCache(
      load: () async {
        if (fail) {
          throw StateError('replacement unavailable');
        }
        return [];
      },
      databaseIdentity: () => identity,
    );
    addTearDown(cache.dispose);
    await cache.refresh();
    identity = Object();
    fail = true;
    await cache.refresh();
    expect(cache.entries, isNull);
    expect(cache.error, isNotNull);
  });
}
