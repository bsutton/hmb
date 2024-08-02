import 'dart:async';

import 'package:flutter/material.dart';

import '../../dao/dao_system.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class SystemIntegrationScreen extends StatefulWidget {
  const SystemIntegrationScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SystemIntegrationScreenState createState() =>
      _SystemIntegrationScreenState();
}

class _SystemIntegrationScreenState extends State<SystemIntegrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _xeroClientIdController = TextEditingController();

  final _xeroClientSecretController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(DaoSystem().get().then((system) {
      _xeroClientIdController.text = system!.xeroClientId ?? '';
      _xeroClientSecretController.text = system.xeroClientSecret ?? '';

      setState(() {});
    }));
  }

  @override
  void dispose() {
    _xeroClientIdController.dispose();
    _xeroClientSecretController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system!.xeroClientId = _xeroClientIdController.text;
      system.xeroClientSecret = _xeroClientSecretController.text;

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
          title: const Text('System Integration'),
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
                  controller: _xeroClientIdController,
                  labelText: 'Xero Client ID',
                  keyboardType: TextInputType.number,
                ),
                HMBTextField(
                  controller: _xeroClientSecretController,
                  labelText: 'Xero Client Secret',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      );
}
