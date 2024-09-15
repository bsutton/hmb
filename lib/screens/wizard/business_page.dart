import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../util/measurement_type.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class WizardBusinessPage extends StatefulWidget {
  const WizardBusinessPage({required this.onNext, super.key});
  final VoidCallback onNext;

  @override
  // ignore: library_private_types_in_public_api
  _WizardBusinessPageState createState() => _WizardBusinessPageState();
}

class _WizardBusinessPageState extends State<WizardBusinessPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;
  late TextEditingController _businessNumberController;
  late TextEditingController _businessNumberLabelController;
  late TextEditingController _webUrlController;
  late TextEditingController _termsUrlController;

  late final System system;

  Future<void> _initialize() async {
    system = (await DaoSystem().get())!;
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
      // Save the form data
      system
        ..businessName = _businessNameController.text
        ..businessNumber = _businessNumberController.text
        ..businessNumberLabel = _businessNumberLabelController.text
        ..webUrl = _webUrlController.text
        ..termsUrl = _termsUrlController.text;

      await DaoSystem().update(system);
      widget.onNext();
    } else {
      HMBToast.error('Fix the errors and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Business Details'),
          automaticallyImplyLeading: false,
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
                        const Text(
                          '''Add your core business details which will appear on invoices, quotes and emails''',
                        ),
                        const SizedBox(height: 16),
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
                        HMBTextField(
                          controller: _webUrlController,
                          labelText: 'Web URL',
                        ),
                        HMBTextField(
                          controller: _termsUrlController,
                          labelText: 'Terms URL',
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
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: widget.onNext,
                              child: const Text('Skip'),
                            ),
                            ElevatedButton(
                              onPressed: _saveForm,
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
        ),
      );
}
