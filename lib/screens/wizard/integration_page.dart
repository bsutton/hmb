import 'package:country_code/country_code.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class WizardIntegrationPage extends StatefulWidget {
  const WizardIntegrationPage({required this.onNext, super.key});
  final VoidCallback onNext;

  @override
  // ignore: library_private_types_in_public_api
  _WizardIntegrationPageState createState() => _WizardIntegrationPageState();
}

class _WizardIntegrationPageState extends State<WizardIntegrationPage> {
  final _formKey = GlobalKey<FormState>();
  late final System system;

  late TextEditingController _xeroClientIdController;
  late TextEditingController _xeroClientSecretController;
  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  @override
  void initState() {
    super.initState();
    _countryCodes = CountryCode.values;
  }

  Future<void> _initialize() async {
    system = (await DaoSystem().get())!;
    _xeroClientIdController = TextEditingController(text: system.xeroClientId);
    _xeroClientSecretController =
        TextEditingController(text: system.xeroClientSecret);
    _selectedCountryCode = system.countryCode ?? 'US';
  }

  @override
  void dispose() {
    _xeroClientIdController.dispose();
    _xeroClientSecretController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      // Save the form data
      system
        ..xeroClientId = _xeroClientIdController.text
        ..xeroClientSecret = _xeroClientSecretController.text
        ..countryCode = _selectedCountryCode;

      await DaoSystem().update(system);
      widget.onNext();
    } else {
      HMBToast.error('Fix the errors and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('System Integration'),
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
                          '''
HMB can generate and (optionally) upload invoices to the Xero Accounting package.
To take advantage of this feature you need to use Xero as your accounting
package and you need a Xero developer account.''',
                        ),
                        const SizedBox(height: 16),
                        HMBTextField(
                          controller: _xeroClientIdController,
                          labelText: 'Xero Client ID',
                          keyboardType: TextInputType.number,
                        ),
                        HMBTextField(
                          controller: _xeroClientSecretController,
                          labelText: 'Xero Client Secret',
                          keyboardType: TextInputType.number,
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
                              child: const Text('Finish'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
        ),
      );
}
