import 'dart:async';

import 'package:country_code/country_code.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../util/measurement_type.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/select/hmb_droplist.dart';

class SystemBusinessScreen extends StatefulWidget {
  const SystemBusinessScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SystemBusinessScreenState createState() => _SystemBusinessScreenState();
}

class _SystemBusinessScreenState extends State<SystemBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  late final System system;
  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  late TextEditingController _businessNameController;
  late TextEditingController _businessNumberController;
  late TextEditingController _businessNumberLabelController;
  late TextEditingController _webUrlController;
  late TextEditingController _termsUrlController;

  bool initialised = false;
  Future<void> _initialize() async {
    if (initialised) {
      return;
    }
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
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessNumberController.dispose();
    _businessNumberLabelController.dispose();
    _webUrlController.dispose();
    _termsUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system!
        ..businessName = _businessNameController.text
        ..businessNumber = _businessNumberController.text
        ..businessNumberLabel = _businessNumberLabelController.text
        ..webUrl = _webUrlController.text
        ..termsUrl = _termsUrlController.text
        ..countryCode = _selectedCountryCode
        ..preferredUnitSystem = system.preferredUnitSystem;

      await DaoSystem().update(system);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      HMBToast.error('Fix the errors and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Business Details'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Colors.purple),
              onPressed: _saveForm,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilderEx(
            // ignore: discarded_futures
            future: _initialize(),
            builder: (context, _) => Form(
              key: _formKey,
              child: ListView(
                children: [
                  HMBTextField(
                    controller: _businessNameController,
                    labelText: 'Business Name',
                  ),
                  HMBTextField(
                    controller: _businessNumberController,
                    labelText: 'Business Number',
                  ),
                  HMBTextField(
                    controller: _businessNumberLabelController,
                    labelText: 'Business Number Label',
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedCountryCode,
                    decoration:
                        const InputDecoration(labelText: 'Country Code'),
                    items: _countryCodes
                        .map((country) => DropdownMenuItem<String>(
                              value: country.alpha2,
                              child: Text(
                                  '''${country.countryName} (${country.alpha2})'''),
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
                    format: (unit) => unit == PreferredUnitSystem.metric
                        ? 'Metric'
                        : 'Imperial',
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
                ],
              ),
            ),
          ),
        ),
      );
}
