import 'dart:async';

import 'package:flutter/material.dart';

import '../../dao/dao_system.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class SystemBusinessScreen extends StatefulWidget {
  const SystemBusinessScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SystemBusinessScreenState createState() => _SystemBusinessScreenState();
}

class _SystemBusinessScreenState extends State<SystemBusinessScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _businessNameController;
  late TextEditingController _businessNumberController;
  late TextEditingController _businessNumberLabelController;
  late TextEditingController _webUrlController;
  late TextEditingController _termsUrlController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(DaoSystem().get().then((system) {
      _businessNameController =
          TextEditingController(text: system!.businessName);
      _businessNumberController =
          TextEditingController(text: system.businessNumber);
      _businessNumberLabelController =
          TextEditingController(text: system.businessNumberLabel);
      _webUrlController = TextEditingController(text: system.webUrl);
      _termsUrlController = TextEditingController(text: system.termsUrl);
      setState(() {});
    }));
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
      system!.businessName = _businessNameController.text;
      system
        ..businessNumber = _businessNumberController.text
        ..businessNumberLabel = _businessNumberLabelController.text
        ..webUrl = _webUrlController.text
        ..termsUrl = _termsUrlController.text;

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
          child: Form(
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
      );
}
