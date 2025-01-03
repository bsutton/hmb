import 'dart:async';

import 'package:country_code/country_code.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
// Import your new classes/enums
import '../../../util/app_title.dart';
import '../../../util/measurement_type.dart';
import '../../widgets/async_state.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/save_and_close.dart';
import '../../widgets/select/hmb_droplist.dart';
import 'operating_hours_ui.dart';

class SystemBusinessScreen extends StatefulWidget {
  const SystemBusinessScreen({super.key, this.showButtons = true});

  final bool showButtons;

  @override
  SystemBusinessScreenState createState() => SystemBusinessScreenState();
}

class SystemBusinessScreenState extends AsyncState<SystemBusinessScreen, void> {
  final _formKey = GlobalKey<FormState>();

  late System system;

  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  // Existing TextEditingControllers
  late TextEditingController? _businessNameController;
  late TextEditingController? _businessNumberController;
  late TextEditingController? _businessNumberLabelController;
  late TextEditingController? _webUrlController;
  late TextEditingController? _termsUrlController;
  late OperatingHoursController? _operatingHoursController;

  // -------------------------------------------
  // 1. Keep a list for toggling day selection
  // -------------------------------------------

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Business Details');

    system = (await DaoSystem().get())!;

    // 1. Populate existing fields
    _countryCodes = CountryCode.values;
    _selectedCountryCode = system.countryCode ?? 'AU';

    _businessNameController = TextEditingController(text: system.businessName);
    _businessNumberController =
        TextEditingController(text: system.businessNumber);
    _businessNumberLabelController =
        TextEditingController(text: system.businessNumberLabel);
    _webUrlController = TextEditingController(text: system.webUrl);
    _termsUrlController = TextEditingController(text: system.termsUrl);

    // 2. Load existing OperatingHours from System, if any
    _operatingHoursController =
        OperatingHoursController(operatingHours: system.getOperatingHours());
  }

  @override
  void dispose() {
    // Dispose of controllers
    _businessNameController?.dispose();
    _businessNumberController?.dispose();
    _businessNumberLabelController?.dispose();
    _webUrlController?.dispose();
    _termsUrlController?.dispose();

    super.dispose();
  }

  // --------------------------------
  // Build your Operating Hours UI
  // --------------------------------
  Widget _buildOperatingHours() =>
      OperatingHoursUi(controller: _operatingHoursController!);

  // --------------------------------
  // Build the entire Form
  // --------------------------------
  FutureBuilderEx<void> _buildForm() => FutureBuilderEx(
        // ignore: discarded_futures
        future: initialised,
        builder: (context, _) => Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Existing fields...
              HMBTextField(
                controller: _businessNameController!,
                labelText: 'Business Name',
              ),
              HelpWrapper(
                tooltip: 'Help for Business Number',
                title: 'What is a Business Number?',
                helpChild: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Your government allocated business registration number.'),
                    HMBSpacer(height: true),
                    Text('Australia: ABN (e.g., 12 345 678 901)'),
                    Text('United States: EIN (e.g., 12-3456789)'),
                    Text('United Kingdom: CRN (e.g., 12345678)'),
                    Text(
                        'Other Countries: Enter your official registration number.'),
                  ],
                ),
                child: HMBTextField(
                  controller: _businessNumberController!,
                  labelText: 'Business Number',
                ),
              ),
              HelpWrapper(
                tooltip: 'Help for Business Number Label',
                title: 'What is a Business Number Label?',
                helpChild: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your government allocated business number'),
                    HMBSpacer(height: true),
                    Text('Examples of labels:'),
                    Text('Australia - ABN'),
                    Text('United States - EIN'),
                    Text('United Kingdom - CRN'),
                  ],
                ),
                child: HMBTextField(
                  controller: _businessNumberLabelController!,
                  labelText: 'Business Number Label',
                ),
              ),
              DropdownButtonFormField<String>(
                value: _selectedCountryCode,
                decoration: const InputDecoration(labelText: 'Country Code'),
                items: _countryCodes
                    .map((country) => DropdownMenuItem<String>(
                          value: country.alpha2,
                          child: Text(
                              '${country.countryName} (${country.alpha2})'),
                        ))
                    .toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCountryCode = newValue!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a country code';
                  }
                  return null;
                },
              ),
              HMBDroplist<PreferredUnitSystem>(
                title: 'Unit System',
                selectedItem: () async => system.preferredUnitSystem,
                format: (unit) =>
                    unit == PreferredUnitSystem.metric ? 'Metric' : 'Imperial',
                items: (filter) async => PreferredUnitSystem.values,
                onChanged: (value) {
                  setState(() {
                    system.preferredUnitSystem = value!;
                  });
                },
              ),
              HMBTextField(
                controller: _webUrlController!,
                labelText: 'Web URL',
              ),
              HMBTextField(
                controller: _termsUrlController!,
                labelText: 'Terms URL',
              ),

              // New Operating Hours Section
              const SizedBox(height: 16),
              _buildOperatingHours(),
            ],
          ),
        ),
      );

  // --------------------------------
  // Final Save Logic
  // --------------------------------
  Future<bool> save({required bool close}) async {
    if (!_formKey.currentState!.validate()) {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }

    // 1. Update fields in the System
    final localSystem = await DaoSystem().get();
    if (localSystem == null) {
      return false;
    }

    localSystem
      ..businessName = _businessNameController!.text
      ..businessNumber = _businessNumberController!.text
      ..businessNumberLabel = _businessNumberLabelController!.text
      ..webUrl = _webUrlController!.text
      ..termsUrl = _termsUrlController!.text
      ..countryCode = _selectedCountryCode
      ..setOperatingHours(_operatingHoursController!.operatingHours);

    // 3. Update in DB
    await DaoSystem().update(localSystem);

    if (mounted) {
      HMBToast.info('saved');
      if (close) {
        context.go('/jobs');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showButtons) {
      return Scaffold(
        body: Column(
          children: [
            SaveAndClose(
              onSave: ({required close}) async => save(close: close),
              showSaveOnly: false,
              onCancel: () async => context.go('/jobs'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(children: [_buildForm()]),
              ),
            ),
          ],
        ),
      );
    } else {
      // For when the form is displayed in a wizard flow
      return _buildForm();
    }
  }
}
