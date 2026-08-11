import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/integrations/google_calendar/google_calendar_sync.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

void main() {
  test('inserts a schedule event when no matching event exists', () async {
    final gateway = _FakeCalendarGateway();
    final draft = _activityDraft();

    await ExternalCalendarSynchronizer(gateway).upsert(draft);

    expect(gateway.inserted, [draft]);
    expect(gateway.updated, isEmpty);
    expect(gateway.lastLookup, ('hmbJobActivityId', '41'));
  });

  test(
    'updates the matching schedule event instead of duplicating it',
    () async {
      final gateway = _FakeCalendarGateway(existingEventId: 'google-event-7');
      final draft = _activityDraft();

      await ExternalCalendarSynchronizer(gateway).upsert(draft);

      expect(gateway.inserted, isEmpty);
      expect(gateway.updated.single, ('google-event-7', draft));
    },
  );

  test('deletes the matching schedule event', () async {
    final gateway = _FakeCalendarGateway(existingEventId: 'google-event-8');

    await ExternalCalendarSynchronizer(
      gateway,
    ).deleteBySource(key: 'hmbJobActivityId', value: '41');

    expect(gateway.deleted, ['google-event-8']);
  });

  test('navigation event identifies one job visit per local day', () {
    final job = _job();
    final site = _site();
    final when = DateTime(2026, 8, 11, 9, 30);

    final draft = ExternalCalendarEventDraft.forNavigation(
      job: job,
      site: site,
      when: when,
    );

    expect(draft.sourceKey, 'hmbNavigationKey');
    expect(draft.sourceValue, '17:20260811');
    expect(draft.location, '1 Test Street, Testville, VIC, 3000');
    expect(draft.end, when.add(const Duration(hours: 1)));
  });
}

ExternalCalendarEventDraft _activityDraft() {
  final activity = JobActivity.forInsert(
    jobId: 17,
    start: DateTime(2026, 8, 11, 9),
    end: DateTime(2026, 8, 11, 11),
    notes: 'Bring the ladder',
  )..id = 41;
  return ExternalCalendarEventDraft.forJobActivity(
    activity: activity,
    job: _job(),
    site: _site(),
  );
}

Job _job() => Job.forInsert(
  customerId: 2,
  summary: 'Repair gutter',
  description: '',
  siteId: 3,
  contactId: 4,
  status: JobStatus.scheduled,
  hourlyRate: Money.fromInt(10000, isoCode: 'AUD'),
  bookingFee: Money.fromInt(0, isoCode: 'AUD'),
  billingContactId: 4,
)..id = 17;

Site _site() => Site.forInsert(
  name: 'Test site',
  addressLine1: '1 Test Street',
  addressLine2: '',
  suburb: 'Testville',
  state: 'VIC',
  postcode: '3000',
  accessDetails: null,
)..id = 3;

class _FakeCalendarGateway implements ExternalCalendarGateway {
  _FakeCalendarGateway({this.existingEventId});

  final String? existingEventId;
  (String, String)? lastLookup;
  final inserted = <ExternalCalendarEventDraft>[];
  final updated = <(String, ExternalCalendarEventDraft)>[];
  final deleted = <String>[];

  @override
  Future<String?> findEventId({
    required String key,
    required String value,
  }) async {
    lastLookup = (key, value);
    return existingEventId;
  }

  @override
  Future<void> insert(ExternalCalendarEventDraft event) async {
    inserted.add(event);
  }

  @override
  Future<void> update(String eventId, ExternalCalendarEventDraft event) async {
    updated.add((eventId, event));
  }

  @override
  Future<void> delete(String eventId) async {
    deleted.add(eventId);
  }

  @override
  void close() {}
}
