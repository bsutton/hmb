import 'package:country_code/country_code.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// import 'package:mobile_number/mobile_number.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../util/money_ex.dart';
import '../../../util/platform_ex.dart';
import '../../dialog/message_template_dialog.dart';
import '../../widgets/fields/hmb_email_field.dart';
import '../../widgets/fields/hmb_money_editing_controller.dart';
import '../../widgets/fields/hmb_money_field.dart';
import '../../widgets/fields/hmb_phone_field.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class SystemEditScreen extends StatefulWidget {
  const SystemEditScreen({required this.system, super.key});
  final System system;

  @override
  // ignore: library_private_types_in_public_api
  _SystemEditScreenState createState() => _SystemEditScreenState();
}

class _SystemEditScreenState extends State<SystemEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fromEmailController;
  late TextEditingController _bsbController;
  late TextEditingController _accountNoController;
  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _suburbController;
  late TextEditingController _stateController;
  late TextEditingController _postcodeController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _landLineController;
  late TextEditingController _officeNumberController;
  late TextEditingController _emailAddressController;
  late TextEditingController _webUrlController;
  late TextEditingController _termsUrlController;
  late TextEditingController _businessNameController;
  late TextEditingController _businessNumberController;
  late TextEditingController _businessNumberLabelController;
  late HMBMoneyEditingController _defaultHourlyRateController;
  late HMBMoneyEditingController _defaultBookingFeeController;
  late TextEditingController _xeroClientIdController;
  late TextEditingController _xeroClientSecretController;
  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    // ignore: discarded_futures
    _countryCodes = CountryCode.values;
  }

  void _initializeControllers() {
    _fromEmailController = TextEditingController(text: widget.system.fromEmail);
    _bsbController = TextEditingController(text: widget.system.bsb);
    _accountNoController = TextEditingController(text: widget.system.accountNo);
    _addressLine1Controller =
        TextEditingController(text: widget.system.addressLine1);
    _addressLine2Controller =
        TextEditingController(text: widget.system.addressLine2);
    _suburbController = TextEditingController(text: widget.system.suburb);
    _stateController = TextEditingController(text: widget.system.state);
    _postcodeController = TextEditingController(text: widget.system.postcode);
    _mobileNumberController =
        TextEditingController(text: widget.system.mobileNumber);
    _landLineController = TextEditingController(text: widget.system.landLine);
    _officeNumberController =
        TextEditingController(text: widget.system.officeNumber);
    _emailAddressController =
        TextEditingController(text: widget.system.emailAddress);
    _webUrlController = TextEditingController(text: widget.system.webUrl);
    _termsUrlController = TextEditingController(text: widget.system.termsUrl);
    _businessNameController =
        TextEditingController(text: widget.system.businessName);
    _businessNumberController =
        TextEditingController(text: widget.system.businessNumber);
    _businessNumberLabelController =
        TextEditingController(text: widget.system.businessNumberLabel);
    _defaultHourlyRateController =
        HMBMoneyEditingController(money: widget.system.defaultHourlyRate);
    _defaultBookingFeeController =
        HMBMoneyEditingController(money: widget.system.defaultBookingFee);
    _xeroClientIdController =
        TextEditingController(text: widget.system.xeroClientId);
    _xeroClientSecretController =
        TextEditingController(text: widget.system.xeroClientSecret);
    _selectedCountryCode = widget.system.countryCode ?? 'AU';
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _fromEmailController.dispose();
    _bsbController.dispose();
    _accountNoController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _suburbController.dispose();
    _stateController.dispose();
    _postcodeController.dispose();
    _mobileNumberController.dispose();
    _landLineController.dispose();
    _officeNumberController.dispose();
    _emailAddressController.dispose();
    _webUrlController.dispose();
    _termsUrlController.dispose();
    _businessNameController.dispose();
    _businessNumberController.dispose();
    _businessNumberLabelController.dispose();
    _defaultHourlyRateController.dispose();
    _defaultBookingFeeController.dispose();
    _xeroClientIdController.dispose();
    _xeroClientSecretController.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      // Save the form data
      widget.system.fromEmail = _fromEmailController.text;
      widget.system.bsb = _bsbController.text;
      widget.system.accountNo = _accountNoController.text;
      widget.system.addressLine1 = _addressLine1Controller.text;
      widget.system.addressLine2 = _addressLine2Controller.text;
      widget.system.suburb = _suburbController.text;
      widget.system.state = _stateController.text;
      widget.system.postcode = _postcodeController.text;
      widget.system.mobileNumber = _mobileNumberController.text;
      widget.system.landLine = _landLineController.text;
      widget.system.officeNumber = _officeNumberController.text;
      widget.system.emailAddress = _emailAddressController.text;
      widget.system.webUrl = _webUrlController.text;
      widget.system.termsUrl = _termsUrlController.text;
      widget.system.defaultHourlyRate =
          MoneyEx.tryParse(_defaultHourlyRateController.text);
      widget.system.defaultBookingFee =
          MoneyEx.tryParse(_defaultBookingFeeController.text);
      widget.system.xeroClientId = _xeroClientIdController.text;
      widget.system.xeroClientSecret = _xeroClientSecretController.text;
      widget.system.businessName = _businessNameController.text;
      widget.system.businessNumber = _businessNumberController.text;
      widget.system.businessNumberLabel = _businessNumberLabelController.text;
      widget.system.countryCode = _selectedCountryCode;

      await DaoSystem().update(widget.system);

      if (mounted) {
        context.go('/jobs');
      }
    } else {
      HMBToast.error('Fixed the errors and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Edit System Entity'),
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
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
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
                HMBTextField(
                    controller: _bsbController,
                    labelText: 'BSB',
                    keyboardType: TextInputType.number),
                HMBTextField(
                  controller: _accountNoController,
                  labelText: 'Account Number',
                  keyboardType: TextInputType.number,
                ),
                HMBMoneyField(
                    controller: _defaultHourlyRateController,
                    labelText: 'Default Hourly Rate',
                    fieldName: 'default hourly rate'),
                HMBMoneyField(
                  controller: _defaultBookingFeeController,
                  labelText: 'Default Booking Fee',
                  fieldName: 'default Booking Fee',
                ),
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
                HMBEmailField(
                    controller: _emailAddressController,
                    required: true,
                    labelText: 'Notice/Backup Email Address'),
                HMBTextField(
                    controller: _webUrlController, labelText: 'Web URL'),
                HMBTextField(
                    controller: _termsUrlController, labelText: 'Terms URL'),
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
                // FutureBuilderEx(
                //   // ignore: discarded_futures
                //   future: getSimCards(),
                //   builder: (context, cards) {
                //     if (cards == null || cards.isEmpty) {
                //       return const Text('No sim cards found');
                //     } else {
                //       return HMBDroplist<SimCard>(
                //         title: 'Sim Card',
                //         selectedItem: () async {
                //           final cards = await getSimCards();
                //           if (cards.isNotEmpty) {
                //             return cards[widget.system.simCardNo ?? 0];
                //           } else {
                //             return null;
                //           }
                //         },
                //         items: (filter) async => getSimCards(),
                //         format: (card) => card.displayName ?? 'Unnamed',
                //         onChanged: (card) =>
                //             widget.system.simCardNo = card?.slotIndex,
                //       );
                //     }
                //   },
                // ),
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
              ],
            ),
          ),
        ),
      );
}
