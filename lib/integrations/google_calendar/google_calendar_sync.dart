/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:googleapis/calendar/v3.dart' as calendar;

import '../../dao/dao_job_activity.dart';
import '../../dao/dao_site.dart';
import '../../database/management/backup_providers/google_drive/google_drive_auth.dart';
import '../../entity/job.dart';
import '../../entity/job_activity.dart';
import '../../entity/site.dart';
import '../../util/dart/app_settings.dart';

enum ExternalCalendarSyncResult { synced, disabled, unavailable }

class ExternalCalendarEventDraft {
  const ExternalCalendarEventDraft({
    required this.summary,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.sourceKey,
    required this.sourceValue,
  });

  factory ExternalCalendarEventDraft.forJobActivity({
    required JobActivity activity,
    required Job job,
    required Site? site,
  }) => ExternalCalendarEventDraft(
    summary: 'Job #${job.id}: ${job.summary}',
    description: [
      'Scheduled by HMB.',
      if (activity.notes case final notes? when notes.trim().isNotEmpty)
        notes.trim(),
    ].join('\n'),
    location: site?.address ?? '',
    start: activity.start,
    end: activity.end,
    sourceKey: 'hmbJobActivityId',
    sourceValue: activity.id.toString(),
  );

  factory ExternalCalendarEventDraft.forNavigation({
    required Job job,
    required Site site,
    required DateTime when,
  }) => ExternalCalendarEventDraft(
    summary: 'Safety location — Job #${job.id}: ${job.summary}',
    description:
        'HMB recorded this location when directions were opened for an '
        'unscheduled visit.',
    location: site.address,
    start: when,
    end: when.add(const Duration(hours: 1)),
    sourceKey: 'hmbNavigationKey',
    sourceValue: '${job.id}:${_dateKey(when)}',
  );

  final String summary;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;
  final String sourceKey;
  final String sourceValue;
}

abstract class ExternalCalendarGateway {
  Future<String?> findEventId({required String key, required String value});

  Future<void> insert(ExternalCalendarEventDraft event);

  Future<void> update(String eventId, ExternalCalendarEventDraft event);

  Future<void> delete(String eventId);

  void close();
}

class ExternalCalendarSynchronizer {
  const ExternalCalendarSynchronizer(this.gateway);

  final ExternalCalendarGateway gateway;

  Future<void> upsert(ExternalCalendarEventDraft event) async {
    final eventId = await gateway.findEventId(
      key: event.sourceKey,
      value: event.sourceValue,
    );
    if (eventId == null) {
      await gateway.insert(event);
    } else {
      await gateway.update(eventId, event);
    }
  }

  Future<void> deleteBySource({
    required String key,
    required String value,
  }) async {
    final eventId = await gateway.findEventId(key: key, value: value);
    if (eventId != null) {
      await gateway.delete(eventId);
    }
  }
}

class GoogleCalendarSyncService {
  Future<ExternalCalendarSyncResult> upsertActivity({
    required JobActivity activity,
    required Job job,
  }) async {
    final site = await DaoSite().getByJob(job);
    return _withSynchronizer(
      (sync) => sync.upsert(
        ExternalCalendarEventDraft.forJobActivity(
          activity: activity,
          job: job,
          site: site,
        ),
      ),
    );
  }

  Future<ExternalCalendarSyncResult> deleteActivity(JobActivity activity) =>
      _withSynchronizer(
        (sync) => sync.deleteBySource(
          key: 'hmbJobActivityId',
          value: activity.id.toString(),
        ),
      );

  Future<ExternalCalendarSyncResult> recordNavigation({
    required Job job,
    required Site site,
    DateTime? when,
  }) async {
    final navigationTime = when ?? DateTime.now();
    if (await DaoJobActivity().hasActivityAt(job.id, navigationTime)) {
      return ExternalCalendarSyncResult.synced;
    }
    return _withSynchronizer(
      (sync) => sync.upsert(
        ExternalCalendarEventDraft.forNavigation(
          job: job,
          site: site,
          when: navigationTime,
        ),
      ),
    );
  }

  Future<ExternalCalendarSyncResult> _withSynchronizer(
    Future<void> Function(ExternalCalendarSynchronizer sync) operation,
  ) async {
    if (!await AppSettings.getGoogleCalendarSyncEnabled()) {
      return ExternalCalendarSyncResult.disabled;
    }
    if (!GoogleDriveAuth.isAuthSupported()) {
      return ExternalCalendarSyncResult.unavailable;
    }
    final auth = await GoogleDriveAuth.instance();
    final headers = await auth.authHeadersOrNull();
    if (headers == null) {
      return ExternalCalendarSyncResult.unavailable;
    }

    final gateway = GoogleCalendarGateway.fromHeaders(headers);
    try {
      await operation(ExternalCalendarSynchronizer(gateway));
      return ExternalCalendarSyncResult.synced;
    } finally {
      gateway.close();
    }
  }
}

class GoogleCalendarGateway implements ExternalCalendarGateway {
  GoogleCalendarGateway._(this._client) : _api = calendar.CalendarApi(_client);

  factory GoogleCalendarGateway.fromHeaders(Map<String, String> headers) =>
      GoogleCalendarGateway._(GoogleAuthClient(headers));

  static const _calendarId = 'primary';

  final GoogleAuthClient _client;
  final calendar.CalendarApi _api;

  @override
  Future<String?> findEventId({
    required String key,
    required String value,
  }) async {
    final events = await _api.events.list(
      _calendarId,
      privateExtendedProperty: ['$key=$value'],
      maxResults: 1,
      showDeleted: false,
    );
    final matches = events.items;
    return matches == null || matches.isEmpty ? null : matches.first.id;
  }

  @override
  Future<void> insert(ExternalCalendarEventDraft event) async {
    await _api.events.insert(_toGoogleEvent(event), _calendarId);
  }

  @override
  Future<void> update(String eventId, ExternalCalendarEventDraft event) async {
    await _api.events.update(_toGoogleEvent(event), _calendarId, eventId);
  }

  @override
  Future<void> delete(String eventId) async {
    await _api.events.delete(_calendarId, eventId);
  }

  calendar.Event _toGoogleEvent(ExternalCalendarEventDraft event) =>
      calendar.Event(
        summary: event.summary,
        description: event.description,
        location: event.location,
        start: calendar.EventDateTime(dateTime: event.start),
        end: calendar.EventDateTime(dateTime: event.end),
        extendedProperties: calendar.EventExtendedProperties(
          private: {event.sourceKey: event.sourceValue},
        ),
      );

  @override
  void close() => _client.close();
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';
