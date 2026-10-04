import 'package:deferred_state/deferred_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/trip_capture_service.dart';
import '../../dao/dao_trip_log.dart';
import '../../entity/trip_log.dart';
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
  final _form = GlobalKey<FormState>();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _homeName = TextEditingController();
  final _rate = TextEditingController();
  var _enabled = false;
  var _maps = false;
  var _period = 'Today';
  var _start = DateTime.now();
  var _end = DateTime.now();
  List<TripLog> _trips = [];

  @override
  Future<void> asyncInitState() async {
    await BlockingUI().runAndWait(() async {
      final settings = await DaoTripLog().settings();
      _enabled = settings.enabled;
      _maps = settings.routeLookupEnabled;
      _latitude.text = settings.home?.latitude.toString() ?? '';
      _longitude.text = settings.home?.longitude.toString() ?? '';
      _homeName.text = settings.homeLabel;
      _rate.text = (settings.rateCentsPerKm / 100).toStringAsFixed(2);
    });
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    if (_enabled && !await TripCaptureService.instance.requestPermission()) {
      HMBToast.error(
        'Location permission is required. Enable it in device settings.',
      );
      return;
    }
    final latitude = double.tryParse(_latitude.text);
    final longitude = double.tryParse(_longitude.text);
    if ((latitude == null) != (longitude == null)) {
      HMBToast.error('Enter both home coordinates, or leave both blank.');
      return;
    }
    await BlockingUI().runAndWait(
      () => DaoTripLog().saveSettings(
        TripSettings(
          enabled: _enabled,
          routeLookupEnabled: _maps,
          home: latitude == null ? null : TripPoint(latitude, longitude!),
          homeLabel: _homeName.text.trim(),
          rateCentsPerKm: (double.parse(_rate.text) * 100).round(),
        ),
      ),
    );
    HMBToast.info('Travel settings saved');
  }

  Future<void> _setHome() async {
    if (!await TripCaptureService.instance.requestPermission()) {
      HMBToast.error('Enable location permission on an Android or iOS device.');
      return;
    }
    final point = await BlockingUI().runAndWait(
      TripCaptureService.instance.currentPoint,
    );
    if (point == null) {
      HMBToast.error('Could not get a location fix.');
      return;
    }
    if (mounted) {
      setState(() {
        _latitude.text = point.latitude.toString();
        _longitude.text = point.longitude.toString();
      });
    }
  }

  Future<void> _classify(TripLog trip) async {
    final result = await showDialog<(bool, String)>(
      context: context,
      builder: (_) => _TripPurposeDialog(trip: trip),
    );
    if (result != null) {
      await BlockingUI().runAndWait(
        () => DaoTripLog().classify(
          trip.id,
          business: result.$1,
          purpose: result.$2,
        ),
      );
      await _reload();
    }
  }

  @override
  void dispose() {
    for (final controller in [_latitude, _longitude, _homeName, _rate]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Trip log',
    maxContentWidth: 800,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load the trip log.'),
      builder: (context) {
        final km =
            _trips.fold<int>(
              0,
              (sum, trip) => sum + (trip.distanceMetres ?? 0),
            ) /
            1000;
        final businessKm =
            _trips
                .where((trip) => trip.business)
                .fold<int>(0, (sum, trip) => sum + (trip.distanceMetres ?? 0)) /
            1000;
        final pending = _trips
            .where((trip) => trip.distanceMetres == null)
            .length;
        final cost = businessKm * (double.tryParse(_rate.text) ?? 0);
        return HMBFormList(
          spacing: HMBSpacing.kSectionGap,
          children: [
            const Text(
              'Checks your location only when you open/resume the app. '
              'Trips over 500 m are logged. This is an approximate record, '
              'Review missed stops and personal travel.',
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.symmetric(
                vertical: HMBSpacing.kFieldGap,
              ),
              title: const Text('Travel settings'),
              children: [
                Form(
                  key: _form,
                  child: HMBFormSection(
                    children: [
                      HMBToggle(
                        label: 'Enable trip logging',
                        hint: 'Opt in to foreground location checks',
                        initialValue: _enabled,
                        onToggled: (value) => _enabled = value,
                      ),
                      HMBToggle(
                        label: 'Use Google road distances',
                        hint: 'Send trip endpoints to Google Routes',
                        initialValue: _maps,
                        onToggled: (value) => _maps = value,
                      ),
                      const Text(
                        'Google lookups send start/end coordinates to Google. '
                        'Requires a Google Maps API key; charges may apply. '
                        'Trip records are stored in your database and backups. '
                        'Off by default. Without lookup, road distances remain '
                        'unknown—not straight-line estimates.',
                      ),
                      HMBTextField(
                        controller: _homeName,
                        labelText: 'Home / starting location name',
                      ),
                      HMBTextField(
                        controller: _latitude,
                        labelText: 'Home latitude (optional)',
                        validator: (value) => _coordinate(value, 90),
                      ),
                      HMBTextField(
                        controller: _longitude,
                        labelText: 'Home longitude (optional)',
                        validator: (value) => _coordinate(value, 180),
                      ),
                      HMBButtonSecondary(
                        label: 'Use current location as home',
                        hint: 'Get a single location fix',
                        onPressed: _setHome,
                      ),
                      HMBTextField(
                        controller: _rate,
                        labelText: 'Cost per km (your own rate)',
                        validator: (value) {
                          final rate = double.tryParse(value ?? '');
                          return rate == null || !rate.isFinite || rate < 0
                              ? 'Enter a non-negative rate'
                              : null;
                        },
                      ),
                      const Text(
                        'Cost estimates are not a tax deduction calculation. '
                        'Trip times are inferred from app openings. First '
                        'departures from home use estimated route duration.',
                      ),
                      HMBButtonPrimary(
                        label: 'Save settings',
                        hint: 'Save trip recording preferences',
                        onPressed: _save,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<String>(
              valueListenable: TripCaptureService.instance.status,
              builder: (_, status, _) => Text(status),
            ),
            HMBFormSection(
              children: [
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
                HMBButtonSecondary(
                  label: 'Retry road distances',
                  hint: 'Retry pending Google lookups when enabled',
                  onPressed: () async {
                    try {
                      await BlockingUI().runAndWait(
                        TripCaptureService.instance.updateRoutes,
                      );
                      await _reload();
                    } catch (_) {
                      HMBToast.error(
                        'Road lookup failed. Check Google Maps setup. '
                        'Trips are retained.',
                      );
                    }
                  },
                ),
              ],
            ),
            Surface(
              padding: const EdgeInsets.all(HMBSpacing.kPageInset),
              child: HMBColumn(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trip summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${km.toStringAsFixed(1)} km · '
                    '${businessKm.toStringAsFixed(1)} business km',
                  ),
                  Text('$pending trips with unknown road distance'),
                  Text(
                    'Business cost estimate: '
                    '${cost.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            for (final trip in _trips)
              Surface(
                child: ListTile(
                  title: Text(
                    DateFormat('EEE d MMM, HH:mm').format(trip.arrivedAt),
                  ),
                  subtitle: Text(
                    [
                      if (trip.distanceMetres == null)
                        'Road distance unknown'
                      else
                        _distanceLabel(trip),
                      'Road distances are route estimates',
                      if (trip.business)
                        'Business'
                      else
                        'Unclassified / personal',
                      if (trip.jobId != null)
                        'Near job #${trip.jobId} (check association)',
                      if (trip.purpose.isNotEmpty) trip.purpose,
                    ].join('\n'),
                  ),
                  trailing: IconButton(
                    tooltip: 'Classify trip',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _classify(trip),
                  ),
                ),
              ),
            if (_trips.isEmpty) const Text('No trips in this period.'),
          ],
        );
      },
    ),
  );

  String? _coordinate(String? text, int limit) {
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    final value = double.tryParse(text);
    return value == null || !value.isFinite || value.abs() > limit
        ? 'Enter a valid coordinate'
        : null;
  }

  String _distanceLabel(TripLog trip) =>
      '${(trip.distanceMetres! / 1000).toStringAsFixed(1)} km';
}

class _TripPurposeDialog extends StatefulWidget {
  final TripLog trip;
  const _TripPurposeDialog({required this.trip});
  @override
  State<_TripPurposeDialog> createState() => _TripPurposeDialogState();
}

class _TripPurposeDialogState extends State<_TripPurposeDialog> {
  late final _notes = TextEditingController(text: widget.trip.purpose);
  late bool _business = widget.trip.business;
  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trip purpose'),
    scrollable: true,
    content: HMBFormSection(
      children: [
        HMBToggle(
          label: 'Business trip',
          hint: 'Confirm business travel',
          initialValue: _business,
          onToggled: (value) => _business = value,
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
        onPressed: () => Navigator.pop(context, (_business, _notes.text)),
      ),
    ],
  );
}
