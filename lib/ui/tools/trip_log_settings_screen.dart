import 'package:deferred_state/deferred_state.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/trip_capture_service.dart';
import '../../dao/dao_system.dart';
import '../../dao/dao_trip_log.dart';
import '../../entity/system.dart';
import '../../entity/trip_log.dart';
import '../../util/dart/measurement_type.dart';
import '../widgets/fields/hmb_text_area.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/layout/hmb_spacing.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/widgets.g.dart';

class TripLogSettingsScreen extends StatefulWidget {
  final bool showButtons;

  const TripLogSettingsScreen({super.key, this.showButtons = true});

  @override
  TripLogSettingsScreenState createState() => TripLogSettingsScreenState();
}

class TripLogSettingsScreenState extends DeferredState<TripLogSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _alternateOrigin = TextEditingController();
  final _rate = TextEditingController();
  late TripSettings _settings;
  late SystemConfiguration _system;
  var _enabled = false;
  var _routeLookupEnabled = false;
  TripOriginType _originType = TripOriginType.businessAddress;
  var _hasMapsKey = false;

  bool get _isImperial =>
      _system.preferredUnitSystem == PreferredUnitSystem.imperial;

  double get _distanceUnitInKm => _isImperial ? 1.609344 : 1;

  @override
  Future<void> asyncInitState() async {
    _settings = await DaoTripLog().settings();
    _system = await DaoSystem().get();
    final credentials = await DaoSystem().getGoogleMapsCredentials();
    _hasMapsKey = credentials.apiKey?.trim().isNotEmpty ?? false;
    _enabled = _settings.enabled;
    _routeLookupEnabled = _settings.routeLookupEnabled;
    _originType = _settings.originType;
    _alternateOrigin.text = _settings.alternateOriginAddress;
    _rate.text = (_settings.rateCentsPerKm / 100 * _distanceUnitInKm)
        .toStringAsFixed(2);
  }

  @override
  void dispose() {
    _alternateOrigin.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
    if (_enabled && !await TripCaptureService.instance.requestPermission()) {
      HMBToast.error(
        'Location permission is required. Enable it in device settings.',
      );
      return false;
    }
    if (_enabled &&
        _originType == TripOriginType.businessAddress &&
        _system.address.trim().isEmpty) {
      HMBToast.error(
        'Enter a business address or choose an alternate trip origin.',
      );
      return false;
    }
    final alternateAddress = _alternateOrigin.text.trim();
    if (_enabled &&
        _originType == TripOriginType.alternateAddress &&
        alternateAddress.isEmpty &&
        _settings.home == null) {
      HMBToast.error('Enter an alternate trip origin address.');
      return false;
    }
    final keepLegacyPoint =
        _originType == TripOriginType.alternateAddress &&
        alternateAddress.isEmpty &&
        _settings.home != null;
    final rate = double.parse(_rate.text);
    final updated = TripSettings(
      enabled: _enabled,
      routeLookupEnabled: _routeLookupEnabled,
      home: keepLegacyPoint ? _settings.home : null,
      homeLabel: _settings.homeLabel,
      originType: _originType,
      alternateOriginAddress: alternateAddress,
      rateCentsPerKm: (rate * 100 / _distanceUnitInKm).round(),
    );
    await BlockingUI().runAndWait(() => DaoTripLog().saveSettings(updated));
    _settings = updated;
    if (_enabled && _routeLookupEnabled) {
      await BlockingUI().runAndWait(TripCaptureService.instance.updateRoutes);
    }
    if (mounted) {
      HMBToast.info('Trip logging settings saved');
      if (close) {
        context.pop();
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showButtons) {
      return HMBFullPageChildScreen(
        title: 'Trip logging settings',
        maxContentWidth: 800,
        actions: const [
          HelpButton.text(
            tooltip: 'Trip logging help',
            dialogTitle: 'About trip logging',
            helpText: _helpText,
          ),
        ],
        child: HMBColumn(
          children: [
            SaveAndClose(
              onSave: ({required close}) async {
                await save(close: close);
              },
              showSaveOnly: false,
              onCancel: () async => context.pop(),
            ),
            Expanded(child: _buildForm()),
          ],
        ),
      );
    }
    return _buildForm();
  }

  Widget _buildForm() => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, _) => const Text('Could not load trip settings.'),
    builder: (context) => Form(
      key: _formKey,
      child: HMBFormList(
        spacing: HMBSpacing.kSectionGap,
        children: [
          Surface(
            padding: const EdgeInsets.all(HMBSpacing.kPageInset),
            child: HMBFormSection(
              children: [
                HMBToggle(
                  label: 'Enable trip logging',
                  hint: 'Record trips when you use HMB',
                  initialValue: _enabled,
                  onToggled: (value) => setState(() => _enabled = value),
                ),
                if (!_enabled)
                  const Text(
                    'When enabled, HMB checks your location when you open or '
                    'resume the app. It does not track continuously.',
                  ),
              ],
            ),
          ),
          if (_enabled) ...[
            Surface(
              padding: const EdgeInsets.all(HMBSpacing.kPageInset),
              child: HMBFormSection(
                children: [
                  Text('Trip origin', style: _sectionStyle(context)),
                  const Text(
                    'Choose the address where trips usually begin. This '
                    'choice does not classify a trip as business or personal.',
                  ),
                  HMBSelectChips<TripOriginType>(
                    label: 'Use',
                    value: _originType,
                    items: TripOriginType.values,
                    format: (value) => switch (value) {
                      TripOriginType.businessAddress => 'Business address',
                      TripOriginType.alternateAddress => 'Alternate address',
                    },
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _originType = value);
                      }
                    },
                  ),
                  if (_originType == TripOriginType.businessAddress)
                    _businessAddress(context)
                  else ...[
                    if (_settings.home != null &&
                        _settings.alternateOriginAddress.isEmpty)
                      Text(
                        'Saved location pin: '
                        '${_settings.home!.latitude.toStringAsFixed(5)}, '
                        '${_settings.home!.longitude.toStringAsFixed(5)}',
                      ),
                    HMBTextArea(
                      controller: _alternateOrigin,
                      labelText: 'Alternate origin address',
                      maxLines: 3,
                    ),
                    if (_alternateOrigin.text.trim().isEmpty &&
                        _settings.home == null)
                      const Text('Enter an address to use as the trip origin.'),
                  ],
                  const Text(
                    'Origin and trip classification are separate. Check the '
                    'tax rules that apply to you before claiming travel.',
                  ),
                ],
              ),
            ),
            Surface(
              padding: const EdgeInsets.all(HMBSpacing.kPageInset),
              child: HMBFormSection(
                children: [
                  Text('Mileage estimate', style: _sectionStyle(context)),
                  HMBTextField(
                    controller: _rate,
                    labelText:
                        'Cost per $_distanceUnitLabel '
                        '(business currency)',
                    keyboardType: TextInputType.number,
                    validator: _rateValidator,
                  ),
                  const Text(
                    'This estimates business travel cost. It does not '
                    'determine tax eligibility.',
                  ),
                ],
              ),
            ),
            Surface(
              padding: const EdgeInsets.all(HMBSpacing.kPageInset),
              child: HMBFormSection(
                children: [
                  Text('Road distance', style: _sectionStyle(context)),
                  HMBToggle(
                    label: 'Calculate road distances with Google Routes',
                    hint: 'Send trip endpoints to Google for road estimates',
                    initialValue: _routeLookupEnabled,
                    onToggled: (value) =>
                        setState(() => _routeLookupEnabled = value),
                  ),
                  const Text(
                    'This is optional. When enabled, your chosen origin '
                    'address (for trips that start there) and trip location '
                    'coordinates are sent to Google Routes. Charges may '
                    'apply. Without it, road distances remain unknown.',
                  ),
                  if (_routeLookupEnabled && !_hasMapsKey)
                    const Text(
                      'Add a Google Maps API key and enable Routes API to '
                      'calculate distances.',
                    ),
                  HMBButtonSecondary(
                    label: 'Google Maps setup',
                    hint: 'Configure Google Maps API credentials',
                    onPressed: _openMapsSettings,
                  ),
                ],
              ),
            ),
          ],
          if (!widget.showButtons)
            const HelpButton.text(
              tooltip: 'Trip logging help',
              dialogTitle: 'About trip logging',
              helpText: _helpText,
            ),
        ],
      ),
    ),
  );

  Widget _businessAddress(BuildContext context) {
    final address = _system.address.trim();
    return HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address.isEmpty)
          const Text(
            'No business address is saved. Enter one in Business Contacts '
            'or choose an alternate origin.',
          )
        else
          Text(address),
        HMBButtonSecondary(
          label: 'Edit business address',
          hint: 'Open Business Contacts',
          onPressed: () => context.push('/home/settings/contact'),
        ),
      ],
    );
  }

  Future<void> _openMapsSettings() async {
    await context.push('/home/settings/integrations/google_maps');
    final credentials = await DaoSystem().getGoogleMapsCredentials();
    if (mounted) {
      setState(
        () => _hasMapsKey = credentials.apiKey?.trim().isNotEmpty ?? false,
      );
    }
  }

  String get _distanceUnitLabel => _isImperial ? 'mile' : 'km';

  TextStyle? _sectionStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium;

  String? _rateValidator(String? value) {
    final rate = double.tryParse(value ?? '');
    return rate == null || !rate.isFinite || rate < 0
        ? 'Enter a non-negative rate'
        : null;
  }

  static const _helpText =
      'HMB checks location when the app opens or resumes. It records trips '
      'over 500 m and does not track continuously. Trip times are inferred '
      'from app activity. Review the details and classify each trip as '
      'Business or Personal. Road distance lookups require Google Maps setup '
      'and remain optional. Check local tax rules before claiming travel.';
}
