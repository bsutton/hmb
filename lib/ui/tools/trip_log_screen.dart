import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/trip_capture_service.dart';
import '../../dao/dao_system.dart';
import '../../dao/dao_trip_log.dart';
import '../../entity/system.dart';
import '../../entity/trip_log.dart';
import '../../util/dart/measurement_type.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/hmb_spacing.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';

class TripLogScreen extends StatefulWidget {
  const TripLogScreen({super.key});

  @override
  State<TripLogScreen> createState() => _TripLogScreenState();
}

class _TripLogScreenState extends DeferredState<TripLogScreen> {
  var _period = 'Today';
  var _start = DateTime.now();
  var _end = DateTime.now();
  var _enabled = false;
  var _routeLookupEnabled = false;
  var _rateCentsPerKm = 0;
  late SystemConfiguration _system;
  List<TripLog> _trips = [];

  bool get _isImperial =>
      _system.preferredUnitSystem == PreferredUnitSystem.imperial;

  double get _kmPerUnit => _isImperial ? 1.609344 : 1;
  String get _distanceUnit => _isImperial ? 'mi' : 'km';

  @override
  Future<void> asyncInitState() async {
    final settings = await DaoTripLog().settings();
    _system = await DaoSystem().get();
    _enabled = settings.enabled;
    _routeLookupEnabled = settings.routeLookupEnabled;
    _rateCentsPerKm = settings.rateCentsPerKm;
    if (_enabled && _routeLookupEnabled) {
      await BlockingUI().runAndWait(TripCaptureService.instance.updateRoutes);
    }
    await _selectPeriod('Today');
  }

  Future<void> _selectPeriod(String? value) async {
    if (value == null) {
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = switch (value) {
      'Yesterday' => (DateTime(now.year, now.month, now.day - 1), today),
      'This week' => (
        DateTime(now.year, now.month, now.day - now.weekday + 1),
        DateTime(now.year, now.month, now.day + 1),
      ),
      'This month' => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
      'Last month' => (
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ),
      'This year' => (DateTime(now.year), DateTime(now.year + 1)),
      'Last year' => (DateTime(now.year - 1), DateTime(now.year)),
      'Custom' => (_start, _end),
      _ => (today, DateTime(now.year, now.month, now.day + 1)),
    };
    _period = value;
    _start = range.$1;
    _end = range.$2;
    await _reload();
  }

  Future<void> _reload() async {
    if (!_end.isAfter(_start)) {
      HMBToast.error('End date must be after start date.');
      return;
    }
    final trips = await BlockingUI().runAndWait(
      () => DaoTripLog().between(_start, _end),
    );
    if (mounted) {
      setState(() => _trips = trips);
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await context.push('/home/tools/trips/settings');
    if (!mounted) {
      return;
    }
    final settings = await DaoTripLog().settings();
    setState(() {
      _enabled = settings.enabled;
      _routeLookupEnabled = settings.routeLookupEnabled;
      _rateCentsPerKm = settings.rateCentsPerKm;
    });
    if (_enabled && _routeLookupEnabled) {
      await BlockingUI().runAndWait(TripCaptureService.instance.updateRoutes);
    }
    await _reload();
  }

  Future<void> _retryRoutes() async {
    await BlockingUI().runAndWait(TripCaptureService.instance.updateRoutes);
    await _reload();
  }

  Future<void> _classify(TripLog trip) async {
    final result = await showDialog<(bool, String)>(
      context: context,
      builder: (_) => _TripPurposeDialog(trip: trip),
    );
    if (result == null) {
      return;
    }
    await BlockingUI().runAndWait(
      () => DaoTripLog().classify(
        trip.id,
        business: result.$1,
        purpose: result.$2,
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Trip log',
    maxContentWidth: 800,
    actions: [
      IconButton(
        tooltip: 'Trip logging settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => unawaited(_openSettings(context)),
      ),
      const HelpButton.text(
        tooltip: 'Trip logging help',
        dialogTitle: 'About trip logging',
        helpText: _helpText,
      ),
    ],
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load the trip log.'),
      builder: (context) {
        final totalMetres = _trips.fold<int>(
          0,
          (sum, trip) => sum + (trip.distanceMetres ?? 0),
        );
        final businessMetres = _trips
            .where((trip) => trip.business)
            .fold<int>(0, (sum, trip) => sum + (trip.distanceMetres ?? 0));
        final pending = _trips.where((trip) => trip.distanceMetres == null);
        final businessDistance = businessMetres / 1000 / _kmPerUnit;
        final cost = businessMetres / 1000 * _rateCentsPerKm / 100;
        return HMBFormList(
          spacing: HMBSpacing.kSectionGap,
          children: [
            _loggingStatus(context),
            ValueListenableBuilder<String>(
              valueListenable: TripCaptureService.instance.status,
              builder: (_, status, _) => Text(status),
            ),
            HMBDroplist<String>(
              title: 'Period',
              selectedItem: () async => _period,
              items: (_) async => [
                'Today',
                'Yesterday',
                'This week',
                'This month',
                'Last month',
                'This year',
                'Last year',
                'Custom',
              ],
              format: (value) => value,
              onChanged: _selectPeriod,
            ),
            if (_period == 'Custom') ...[
              HMBDateTimeField(
                label: 'From',
                initialDateTime: _start,
                mode: HMBDateTimeFieldMode.dateOnly,
                onChanged: (value) =>
                    _start = DateTime(value.year, value.month, value.day),
              ),
              HMBDateTimeField(
                label: 'Until (exclusive)',
                initialDateTime: _end,
                mode: HMBDateTimeFieldMode.dateOnly,
                onChanged: (value) =>
                    _end = DateTime(value.year, value.month, value.day),
              ),
            ],
            HMBButtonSecondary(
              label: 'Refresh trips',
              hint: 'Refresh the trip summary',
              onPressed: _reload,
            ),
            Surface(
              padding: const EdgeInsets.all(HMBSpacing.kPageInset),
              child: HMBFormSection(
                children: [
                  Text(
                    'Total distance: '
                    '${(totalMetres / 1000 / _kmPerUnit).toStringAsFixed(1)} '
                    '$_distanceUnit',
                  ),
                  Text(
                    'Business distance: '
                    '${businessDistance.toStringAsFixed(1)} $_distanceUnit',
                  ),
                  Text('Business cost estimate: ${cost.toStringAsFixed(2)}'),
                  Text('${pending.length} trips with unknown road distance'),
                ],
              ),
            ),
            if (pending.isNotEmpty && !_routeLookupEnabled)
              Surface(
                child: HMBColumn(
                  children: [
                    const Text(
                      'Road distance lookup is off. Enable Google Routes in '
                      'Trip logging settings to calculate road distances.',
                    ),
                    HMBButtonSecondary(
                      label: 'Trip logging settings',
                      hint: 'Configure road distance lookup',
                      onPressed: () => _openSettings(context),
                    ),
                  ],
                ),
              ),
            if (_routeLookupEnabled && pending.isNotEmpty)
              HMBButtonSecondary(
                label: 'Retry unknown distances',
                hint: 'Retry Google Routes lookups for pending trips',
                onPressed: _retryRoutes,
              ),
            for (final trip in _trips) _tripCard(trip),
            if (_trips.isEmpty)
              const Surface(child: Text('No trips in this period.')),
            const Text(
              'Distances are route estimates. Review trips and local tax '
              'rules before using totals for a claim.',
            ),
          ],
        );
      },
    ),
  );

  Widget _loggingStatus(BuildContext context) => Surface(
    padding: const EdgeInsets.all(HMBSpacing.kPageInset),
    child: HMBFormSection(
      children: [
        Text(
          _enabled ? 'Trip logging is on' : 'Trip logging is off',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          _enabled
              ? 'HMB checks your location when you open or resume the app.'
              : 'HMB can record trips over 500 m while you use the app. '
                    'Location is not tracked continuously.',
        ),
        if (!_enabled)
          HMBButtonPrimary(
            label: 'Set up trip logging',
            hint: 'Choose whether to enable trip logging',
            onPressed: () => _openSettings(context),
          ),
      ],
    ),
  );

  Widget _tripCard(TripLog trip) => Surface(
    padding: const EdgeInsets.all(HMBSpacing.kPageInset),
    child: HMBFormSection(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEE d MMM, HH:mm').format(trip.arrivedAt),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(_classificationLabel(trip)),
          ],
        ),
        Text(
          trip.distanceMetres == null
              ? 'Road distance unknown'
              : _distanceLabel(trip),
        ),
        if (trip.jobId != null) Text('Near job #${trip.jobId} (check match)'),
        if (trip.purpose.isNotEmpty) Text(trip.purpose),
        Wrap(
          spacing: HMBSpacing.kRelated,
          runSpacing: HMBSpacing.kRelated,
          children: [
            HMBButtonSecondary(
              label: trip.classified ? 'Edit classification' : 'Classify trip',
              hint: 'Choose Business or Personal and add trip notes',
              onPressed: () => _classify(trip),
            ),
            if (trip.distanceMetres == null && _routeLookupEnabled)
              HMBButtonSecondary(
                label: 'Retry distance',
                hint: 'Retry the road distance lookup for this trip',
                onPressed: _retryRoutes,
              ),
          ],
        ),
      ],
    ),
  );

  String _classificationLabel(TripLog trip) => !trip.classified
      ? 'Needs review'
      : trip.business
      ? 'Business'
      : 'Personal';

  String _distanceLabel(TripLog trip) =>
      '${(trip.distanceMetres! / 1000 / _kmPerUnit).toStringAsFixed(1)} '
      '$_distanceUnit · route estimate';

  static const _helpText =
      'HMB checks location when the app opens or resumes. Trips over 500 m '
      'are recorded. It does not track continuously. Trip times are inferred '
      'from app activity. Review each trip and classify it as Business or '
      'Personal. Road distance lookup is optional and requires Google Maps '
      'setup. Check local tax rules before claiming travel.';
}

class _TripPurposeDialog extends StatefulWidget {
  final TripLog trip;

  const _TripPurposeDialog({required this.trip});

  @override
  State<_TripPurposeDialog> createState() => _TripPurposeDialogState();
}

class _TripPurposeDialogState extends State<_TripPurposeDialog> {
  late final _notes = TextEditingController(text: widget.trip.purpose);
  bool? _business;

  @override
  void initState() {
    super.initState();
    if (widget.trip.classified) {
      _business = widget.trip.business;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Classify trip'),
    scrollable: true,
    content: HMBColumn(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Choose how to record this trip.'),
        HMBSelectChips<bool>(
          label: 'Trip type',
          value: _business,
          items: const [true, false],
          format: (business) => business ? 'Business' : 'Personal',
          onChanged: (value) => setState(() => _business = value),
        ),
        HMBTextField(controller: _notes, labelText: 'Purpose / notes'),
      ],
    ),
    actions: [
      HMBCancelButton(
        hint: 'Keep current details',
        onPressed: () => Navigator.pop(context),
      ),
      HMBButtonPrimary(
        label: 'Save',
        hint: 'Save trip classification',
        enabled: _business != null,
        onPressed: () => Navigator.pop(context, (_business!, _notes.text)),
      ),
    ],
  );
}
