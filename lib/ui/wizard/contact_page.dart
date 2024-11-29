import 'package:country_code/country_code.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:mobile_number/mobile_number.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../util/platform_ex.dart';
import '../../util/sim_cards.dart';
import '../dialog/message_template_dialog.dart';
import '../widgets/fields/hmb_email_field.dart';
import '../widgets/fields/hmb_phone_field.dart';
import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/select/hmb_droplist.dart';

class WizardContactPage extends StatefulWidget {
  const WizardContactPage({required this.onNext, super.key});
  final VoidCallback onNext;

  @override
  // ignore: library_private_types_in_public_api
  _WizardContactPageState createState() => _WizardContactPageState();
}

class _WizardContactPageState extends State<WizardContactPage> {
  final _formKey = GlobalKey<FormState>();
  late final System system;

  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _suburbController;
  late TextEditingController _stateController;
  late TextEditingController _postcodeController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _landLineController;
  late TextEditingController _officeNumberController;
  late TextEditingController _fromEmailController;
  late TextEditingController _emailAddressController;
  late TextEditingController _firstNameController; // New controller
  late TextEditingController _surnameController; // New controller

  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  Future<void> _initialize() async {
    system = (await DaoSystem().get())!;
    _addressLine1Controller = TextEditingController(text: system.addressLine1);
    _addressLine2Controller = TextEditingController(text: system.addressLine2);
    _suburbController = TextEditingController(text: system.suburb);
    _stateController = TextEditingController(text: system.state);
    _postcodeController = TextEditingController(text: system.postcode);
    _mobileNumberController = TextEditingController(text: system.mobileNumber);
    _landLineController = TextEditingController(text: system.landLine);
    _officeNumberController = TextEditingController(text: system.officeNumber);
    _fromEmailController = TextEditingController(text: system.fromEmail);
    _emailAddressController = TextEditingController(text: system.emailAddress);
    _firstNameController =
        TextEditingController(text: system.firstname); // Initialize
    _surnameController =
        TextEditingController(text: system.surname); // Initialize

    _selectedCountryCode = system.countryCode ?? 'AU';
    _countryCodes = CountryCode.values;
  }

  @override
  void dispose() {
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _suburbController.dispose();
    _stateController.dispose();
    _postcodeController.dispose();
    _mobileNumberController.dispose();
    _landLineController.dispose();
    _officeNumberController.dispose();
    _fromEmailController.dispose();
    _emailAddressController.dispose();
    _firstNameController.dispose(); // Dispose
    _surnameController.dispose(); // Dispose
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      // Save the form data
      system
        ..firstname = _firstNameController.text // Save first name
        ..surname = _surnameController.text // Save surname
        ..addressLine1 = _addressLine1Controller.text
        ..addressLine2 = _addressLine2Controller.text
        ..suburb = _suburbController.text
        ..state = _stateController.text
        ..postcode = _postcodeController.text
        ..mobileNumber = _mobileNumberController.text
        ..landLine = _landLineController.text
        ..officeNumber = _officeNumberController.text
        ..countryCode = _selectedCountryCode
        ..fromEmail = _fromEmailController.text
        ..emailAddress = _emailAddressController.text;

      await DaoSystem().update(system);
      widget.onNext();
    } else {
      HMBToast.error('Fix the errors and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Contact Information'),
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
                          '''This screen collects contact information, including your address and phone numbers. This data is used for communication and correspondence.''',
                        ),
                        HMBTextField(
                          controller: _firstNameController,
                          labelText: 'First Name',
                          required: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your first name';
                            }
                            return null;
                          },
                        ),
                        HMBTextField(
                          controller: _surnameController,
                          labelText: 'Surname',
                          required: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your surname';
                            }
                            return null;
                          },
                        ),
                        HMBEmailField(
                          autofocus: isNotMobile,
                          controller: _fromEmailController,
                          labelText: 'From Email',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a from email';
                            }
                            return null;
                          },
                        ),
                        HMBEmailField(
                            controller: _emailAddressController,
                            required: true,
                            labelText: 'Notice/Backup Email Address'),
                        HMBPhoneField(
                            controller: _mobileNumberController,
                            labelText: 'Mobile Number',
                            messageData: MessageData()),
                        HMBPhoneField(
                            controller: _landLineController,
                            labelText: 'Land Line',
                            messageData: MessageData()),
                        HMBPhoneField(
                            controller: _officeNumberController,
                            labelText: 'Office Number',
                            messageData: MessageData()),
                        const SizedBox(height: 16),
                        HMBTextField(
                          controller: _addressLine1Controller,
                          labelText: 'Address Line 1',
                          keyboardType: TextInputType.streetAddress,
                        ),
                        HMBTextField(
                            controller: _addressLine2Controller,
                            labelText: 'Address Line 2',
                            keyboardType: TextInputType.streetAddress),
                        HMBTextField(
                          controller: _suburbController,
                          labelText: 'Suburb',
                          keyboardType: TextInputType.name,
                        ),
                        HMBTextField(
                          controller: _stateController,
                          labelText: 'State',
                          keyboardType: TextInputType.name,
                        ),
                        HMBTextField(
                            controller: _postcodeController,
                            labelText: 'Post/Zip code',
                            keyboardType: TextInputType.number),
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
                        FutureBuilderEx(
                          // ignore: discarded_futures
                          future: getSimCards(),
                          builder: (context, cards) {
                            if (cards == null || cards.isEmpty) {
                              return const Text('No sim cards found');
                            } else {
                              return HMBDroplist<SimCard>(
                                title: 'Sim Card',
                                selectedItem: () async {
                                  final cards = await getSimCards();
                                  if (cards.isNotEmpty) {
                                    return cards[system.simCardNo ?? 0];
                                  } else {
                                    return null;
                                  }
                                },
                                items: (filter) async => getSimCards(),
                                format: (card) => card.displayName ?? 'Unnamed',
                                onChanged: (card) =>
                                    system.simCardNo = card?.slotIndex,
                              );
                            }
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
