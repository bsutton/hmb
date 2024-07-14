import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../util/money_ex.dart';
import '../../widgets/hmb_money_editing_controller.dart';
import '../../widgets/hmb_money_field.dart';
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
  }

  @override
  void dispose() {
    _defaultHourlyRateController.dispose();
    _defaultCallOutFeeController.dispose();
    _bsbController.dispose();
    _accountNoController.dispose();
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
        ..accountNo = _accountNoController.text;

      await DaoSystem().update(system);
      widget.onNext();
    } else {
      HMBToast.error('Fix the errors and try again.');
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
