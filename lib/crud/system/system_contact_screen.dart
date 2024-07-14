import 'dart:async';

import 'package:flutter/material.dart';

import '../../dao/dao_system.dart';
import '../../widgets/hmb_phone_field.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class SystemContactInformationScreen extends StatefulWidget {
  const SystemContactInformationScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SystemContactInformationScreenState createState() =>
      _SystemContactInformationScreenState();
}

class _SystemContactInformationScreenState
    extends State<SystemContactInformationScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _addressLine1Controller;
  late TextEditingController _addressLine2Controller;
  late TextEditingController _suburbController;
  late TextEditingController _stateController;
  late TextEditingController _postcodeController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _landLineController;
  late TextEditingController _officeNumberController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(DaoSystem().get().then((system) {
      _addressLine1Controller =
          TextEditingController(text: system!.addressLine1);
      _addressLine2Controller =
          TextEditingController(text: system.addressLine2);
      _suburbController = TextEditingController(text: system.suburb);
      _stateController = TextEditingController(text: system.state);
      _postcodeController = TextEditingController(text: system.postcode);
      _mobileNumberController =
          TextEditingController(text: system.mobileNumber);
      _landLineController = TextEditingController(text: system.landLine);
      _officeNumberController =
          TextEditingController(text: system.officeNumber);
      setState(() {});
    }));
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
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system!.addressLine1 = _addressLine1Controller.text;
      system
        ..addressLine2 = _addressLine2Controller.text
        ..suburb = _suburbController.text
        ..state = _stateController.text
        ..postcode = _postcodeController.text
        ..mobileNumber = _mobileNumberController.text
        ..landLine = _landLineController.text
        ..officeNumber = _officeNumberController.text;

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
          title: const Text('Contact Information'),
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
                HMBPhoneField(
                    controller: _mobileNumberController,
                    labelText: 'Mobile Number'),
                HMBPhoneField(
                    controller: _landLineController, labelText: 'Land Line'),
                HMBPhoneField(
                    controller: _officeNumberController,
                    labelText: 'Office Number'),
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
              ],
            ),
          ),
        ),
      );
}
