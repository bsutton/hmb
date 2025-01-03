import 'dart:async';

import 'package:country_code/country_code.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../util/app_title.dart';
import '../../../util/measurement_type.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/save_and_close.dart';
import '../../widgets/select/hmb_droplist.dart';

class SystemBusinessScreen extends StatefulWidget {
  const SystemBusinessScreen({super.key, this.showButtons = true});

  final bool showButtons;

  @override
  SystemBusinessScreenState createState() => SystemBusinessScreenState();
}

class SystemBusinessScreenState extends State<SystemBusinessScreen> {
  final _formKey = GlobalKey<FormState>();

  late System system;

  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  // Existing TextEditingControllers
  late TextEditingController _businessNameController;
  late TextEditingController _businessNumberController;
  late TextEditingController _businessNumberLabelController;
  late TextEditingController _webUrlController;
  late TextEditingController _termsUrlController;

  bool initialised = false;
  // -------------------------------------------
  // 1. Keep a list for toggling day selection
  // -------------------------------------------
  final List<bool> _selectedDays = List.generate(7, (_) => false);

  // 2. Keep a Map of start/end times for each day
  final Map<DayName, TimeOfDay?> _startTimes = {};
  final Map<DayName, TimeOfDay?> _endTimes = {};

  // 3. In a known order for easy indexing
  final List<DayName> _dayOrder = [
    DayName.mon,
    DayName.tue,
    DayName.wed,
    DayName.thu,
    DayName.fri,
    DayName.sat,
    DayName.sun,
  ];

  Future<void> _initialize() async {
    if (initialised) {
      return;
    }
    setAppTitle('Business Details');
    initialised = true;
    system = (await DaoSystem().get())!;
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
    final existing = OperatingHours.fromJson(system.operatingHours);

    // For each OperatingDay in the existing schedule, populate local state
    for (final od in existing.days) {
      // Find the index in _dayOrder
      final i = _dayOrder.indexOf(od.dayName);
      if (i >= 0) {
        _selectedDays[i] = true;

        // Parse the string "08:00" into TimeOfDay if needed
        if (od.start != null) {
          _startTimes[od.dayName] = _stringToTimeOfDay(od.start!);
        }
        if (od.end != null) {
          _endTimes[od.dayName] = _stringToTimeOfDay(od.end!);
        }
      }
    }
  }

  @override
  void dispose() {
    // Dispose of controllers
    _businessNameController.dispose();
    _businessNumberController.dispose();
    _businessNumberLabelController.dispose();
    _webUrlController.dispose();
    _termsUrlController.dispose();
    super.dispose();
  }

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
      ..businessName = _businessNameController.text
      ..businessNumber = _businessNumberController.text
      ..businessNumberLabel = _businessNumberLabelController.text
      ..webUrl = _webUrlController.text
      ..termsUrl = _termsUrlController.text
      ..countryCode = _selectedCountryCode;

    // 2. Build up an OperatingHours object from local UI state
    final selectedDays = <OperatingDay>[];
    for (var i = 0; i < _dayOrder.length; i++) {
      if (_selectedDays[i]) {
        final dayEnum = _dayOrder[i];
        final startTod = _startTimes[dayEnum];
        final endTod = _endTimes[dayEnum];

        // Convert TimeOfDay to "HH:mm" strings
        final startStr =
            (startTod != null) ? _timeOfDayToString(startTod) : null;
        final endStr = (endTod != null) ? _timeOfDayToString(endTod) : null;

        selectedDays.add(
          OperatingDay(dayName: dayEnum, start: startStr, end: endStr),
        );
      }
    }

    final oh = OperatingHours(days: selectedDays);
    localSystem.operatingHours = oh.toJson();

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

  // Utility: convert "08:00" to TimeOfDay
  TimeOfDay _stringToTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  // Utility: convert TimeOfDay to "08:00" string
  String _timeOfDayToString(TimeOfDay tod) {
    final hourStr = tod.hour.toString().padLeft(2, '0');
    final minStr = tod.minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr';
  }

  Future<void> _selectTime(
      BuildContext context, DayName dayName, bool isStart) async {
    final initialTime = TimeOfDay.now();
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (selectedTime != null) {
      setState(() {
        if (isStart) {
          _startTimes[dayName] = selectedTime;
        } else {
          _endTimes[dayName] = selectedTime;
        }
      });
    }
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
                onCancel: () async => context.go('/jobs')),
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

  // --------------------------------
  // Build your Operating Hours UI
  // --------------------------------
  Widget _buildOperatingHours() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operating Days and Hours',
              style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          ToggleButtons(
            isSelected: _selectedDays,
            onPressed: (index) {
              setState(() {
                _selectedDays[index] = !_selectedDays[index];
              });
            },
            children: _dayOrder.map((d) => Text(d.shortName)).toList(),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(_dayOrder.length, (index) {
              if (!_selectedDays[index]) {
                return const SizedBox.shrink();
              }
              final day = _dayOrder[index];
              final start = _startTimes[day];
              final end = _endTimes[day];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () async =>
                              _selectTime(context, day, true),
                          child: Text(
                            start != null
                                ? _timeOfDayToString(start)
                                : 'Start Time',
                          ),
                        ),
                      ),
                      const Text(' to '),
                      Expanded(
                        child: TextButton(
                          onPressed: () async =>
                              _selectTime(context, day, false),
                          child: Text(
                            end != null ? _timeOfDayToString(end) : 'End Time',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                ],
              );
            }),
          ),
        ],
      );

  // --------------------------------
  // Build the entire Form
  // --------------------------------
  FutureBuilderEx<void> _buildForm() => FutureBuilderEx(
        // ignore: discarded_futures
        future: _initialize(),
        builder: (context, _) => Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HMBTextField(
                controller: _businessNameController,
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
                    controller: _businessNumberController,
                    labelText: 'Business Number',
                  )),
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
                  controller: _businessNumberLabelController,
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
                controller: _webUrlController,
                labelText: 'Web URL',
              ),
              HMBTextField(
                controller: _termsUrlController,
                labelText: 'Terms URL',
              ),

              // New Operating Hours Section
              const SizedBox(height: 16),
              _buildOperatingHours(),
            ],
          ),
        ),
      );
}
