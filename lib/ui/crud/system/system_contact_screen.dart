/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:country_code2/country_code2.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// import 'package:mobile_number/mobile_number.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../util/app_title.dart';
import '../../../util/platform_ex.dart';
import '../../dialog/source_context.dart';
import '../../widgets/fields/hmb_email_field.dart';
import '../../widgets/fields/hmb_phone_field.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/save_and_close.dart';

class SystemContactInformationScreen extends StatefulWidget {
  const SystemContactInformationScreen({super.key, this.showButtons = true});

  final bool showButtons;
  @override
  // ignore: library_private_types_in_public_api
  SystemContactInformationScreenState createState() =>
      SystemContactInformationScreenState();
}

class SystemContactInformationScreenState
    extends DeferredState<SystemContactInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController? _addressLine1Controller;
  late TextEditingController? _addressLine2Controller;
  late TextEditingController? _suburbController;
  late TextEditingController? _stateController;
  late TextEditingController? _postcodeController;
  late TextEditingController? _mobileNumberController;
  late TextEditingController? _landLineController;
  late TextEditingController? _officeNumberController;
  late TextEditingController? _fromEmailController;
  late TextEditingController? _emailAddressController;
  late TextEditingController? _firstNameController; // New controller
  late TextEditingController? _surnameController; // New controller

  late String _selectedCountryCode;
  late List<CountryCode> _countryCodes;

  late final System system;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Business Contacts');
    system = await DaoSystem().get();

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
    _firstNameController = TextEditingController(text: system.firstname);
    _surnameController = TextEditingController(text: system.surname);

    _selectedCountryCode = system.countryCode ?? 'AU';
    _countryCodes = CountryCode.values;
  }

  @override
  void dispose() {
    _addressLine1Controller?.dispose();
    _addressLine2Controller?.dispose();
    _suburbController?.dispose();
    _stateController?.dispose();
    _postcodeController?.dispose();
    _mobileNumberController?.dispose();
    _landLineController?.dispose();
    _officeNumberController?.dispose();
    _fromEmailController?.dispose();
    _emailAddressController?.dispose();
    _firstNameController?.dispose(); // Dispose
    _surnameController?.dispose(); // Dispose
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system
        ..firstname = _firstNameController
            ?.text // Save first name
        ..surname = _surnameController
            ?.text // Save surname
        ..addressLine1 = _addressLine1Controller?.text
        ..addressLine2 = _addressLine2Controller?.text
        ..suburb = _suburbController?.text
        ..state = _stateController?.text
        ..postcode = _postcodeController?.text
        ..countryCode = _selectedCountryCode
        ..mobileNumber = _mobileNumberController?.text
        ..landLine = _landLineController?.text
        ..officeNumber = _officeNumberController?.text
        ..fromEmail = _fromEmailController?.text
        ..emailAddress = _emailAddressController?.text.toLowerCase();

      await DaoSystem().update(system);
      if (mounted) {
        HMBToast.info('saved');
        if (close) {
          context.go('/home/settings');
        }
      }
      return true;
    } else {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showButtons) {
      return Scaffold(
        body: Column(
          children: [
            SaveAndClose(
              onSave: save,
              showSaveOnly: false,
              onCancel: () async => context.pop(),
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
      /// For when the form is displayed in the system wizard
      return _buildForm();
    }
  }

  DeferredBuilder _buildForm() => DeferredBuilder(
    this,
    builder: (context) => Form(
      key: _formKey,
      child: Column(
        children: [
          HMBTextField(
            controller: _firstNameController!,
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
            controller: _surnameController!,
            labelText: 'Surname',
            required: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your surname';
              }
              return null;
            },
          ),
          HMBPhoneField(
            controller: _mobileNumberController!,
            labelText: 'Mobile Number',
            sourceContext: SourceContext(),
          ),
          HMBPhoneField(
            controller: _landLineController!,
            labelText: 'Land Line',
            sourceContext: SourceContext(),
          ),
          HMBPhoneField(
            controller: _officeNumberController!,
            labelText: 'Office Number',
            sourceContext: SourceContext(),
          ),
          HMBEmailField(
            autofocus: isNotMobile,
            controller: _fromEmailController!,
            labelText: 'From Email',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a from email';
              }
              return null;
            },
          ).help(
            'From Email',
            '''
The Email address that will be used when you send an email to your customer.''',
          ),
          HMBEmailField(
            controller: _emailAddressController!,
            required: true,
            labelText: 'Notice/Backup Email Address',
          ).help('Notice/Backup Eamil Address', '''
The email address used to send you notices such as a successful backup.'''),
          HMBTextField(
            controller: _addressLine1Controller!,
            labelText: 'Address Line 1',
            keyboardType: TextInputType.streetAddress,
          ),
          HMBTextField(
            controller: _addressLine2Controller!,
            labelText: 'Address Line 2',
            keyboardType: TextInputType.streetAddress,
          ),
          HMBTextField(
            controller: _suburbController!,
            labelText: 'Suburb',
            keyboardType: TextInputType.name,
          ),
          HMBTextField(
            controller: _stateController!,
            labelText: 'State',
            keyboardType: TextInputType.name,
          ),
          HMBTextField(
            controller: _postcodeController!,
            labelText: 'Post/Zip code',
            keyboardType: TextInputType.number,
          ),

          DropdownButtonFormField<String>(
            initialValue: _selectedCountryCode,
            decoration: const InputDecoration(labelText: 'Country Code'),
            items: _countryCodes
                .map(
                  (country) => DropdownMenuItem<String>(
                    value: country.alpha2,
                    child: Text('${country.countryName} (${country.alpha2})'),
                  ),
                )
                .toList(),
            onChanged: (newValue) {
              _selectedCountryCode = newValue!;
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a country code';
              }
              return null;
            },
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
          //             return cards[system.simCardNo ?? 0];
          //           } else {
          //             return null;
          //           }
          //         },
          //         items: (filter) async => getSimCards(),
          //         format: (card) => card.displayName ?? 'Unnamed',
          //         onChanged: (card) =>
          //             system.simCardNo = card?.slotIndex,
          //       );
          //     }
          //   },
          // ),
        ],
      ),
    ),
  );
}
