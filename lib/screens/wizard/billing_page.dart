import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../util/money_ex.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_money_editing_controller.dart';
import '../../widgets/hmb_money_field.dart';
import '../../widgets/hmb_text.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class WizardBillingPage extends StatefulWidget {
  const WizardBillingPage({required this.onNext, super.key});
  final VoidCallback onNext;

  @override
  // ignore: library_private_types_in_public_api
  _WizardBillingPageState createState() => _WizardBillingPageState();
}

class _WizardBillingPageState extends State<WizardBillingPage> {
  final _formKey = GlobalKey<FormState>();

  late HMBMoneyEditingController _defaultHourlyRateController;
  late HMBMoneyEditingController _defaultCallOutFeeController;
  late TextEditingController _bsbController;
  late TextEditingController _accountNoController;
  late TextEditingController _logoPathController;
  LogoAspectRatio _logoType = LogoAspectRatio.square;
  File? _logoFile;

  late final System system;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initialize() async {
    system = (await DaoSystem().get())!;
    _defaultHourlyRateController =
        HMBMoneyEditingController(money: system.defaultHourlyRate);
    _defaultCallOutFeeController =
        HMBMoneyEditingController(money: system.defaultCallOutFee);
    _bsbController = TextEditingController(text: system.bsb);
    _accountNoController = TextEditingController(text: system.accountNo);
    _logoPathController = TextEditingController(text: system.logoPath);
    _logoType = system.logoAspectRatio;
  }

  @override
  void dispose() {
    _defaultHourlyRateController.dispose();
    _defaultCallOutFeeController.dispose();
    _bsbController.dispose();
    _accountNoController.dispose();
    _logoPathController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      // Save the form data
      system
        ..defaultHourlyRate =
            MoneyEx.tryParse(_defaultHourlyRateController.text)
        ..defaultCallOutFee =
            MoneyEx.tryParse(_defaultCallOutFeeController.text)
        ..bsb = _bsbController.text
        ..accountNo = _accountNoController.text
        ..logoAspectRatio = _logoType;

      if (_logoFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final logoPath =
            '${directory.path}/logo/${_logoFile!.path.split('/').last}';
        _logoFile!.copySync(logoPath);
        system.logoPath = logoPath;
      }

      await DaoSystem().update(system);
      widget.onNext();
    } else {
      HMBToast.error('Fix the errors and try again.');
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
        _logoPathController.text = pickedFile.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Billing Details'),
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
                          '''Billing details used to calculate charges and collect fees''',
                        ),
                        const SizedBox(height: 16),
                        HMBMoneyField(
                            controller: _defaultHourlyRateController,
                            labelText: 'Default Hourly Rate',
                            fieldName: 'default hourly rate'),
                        HMBMoneyField(
                          controller: _defaultCallOutFeeController,
                          labelText: 'Default Call Out Fee',
                          fieldName: 'default call out fee',
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
                        const SizedBox(height: 20),
                        const Text('Logo Type'),
                        HMBDroplist<LogoAspectRatio>(
                          title: 'Logo Aspect Ratio',
                          initialItem: () async => _logoType,
                          items: (filter) async => LogoAspectRatio.values,
                          format: (logoType) => logoType.name,
                          onChanged: (value) {
                            setState(() {
                              _logoType = value ?? LogoAspectRatio.square;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        const HMBText('Logo Path'),
                        TextButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Logo'),
                          onPressed: _pickLogo,
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
