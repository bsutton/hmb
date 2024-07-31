import 'dart:async';

import 'package:flutter/material.dart';

import '../../dao/dao_system.dart';
import '../../util/money_ex.dart';
import '../../widgets/hmb_money_editing_controller.dart';
import '../../widgets/hmb_money_field.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_toast.dart';

class SystemBillingScreen extends StatefulWidget {
  const SystemBillingScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SystemBillingScreenState createState() => _SystemBillingScreenState();
}

class _SystemBillingScreenState extends State<SystemBillingScreen> {
  final _formKey = GlobalKey<FormState>();

  late final HMBMoneyEditingController _defaultHourlyRateController =
      HMBMoneyEditingController();
  late final HMBMoneyEditingController _defaultCallOutFeeController =
      HMBMoneyEditingController();
  late final TextEditingController _bsbController = TextEditingController();
  late final TextEditingController _accountNoController =
      TextEditingController();
  late final TextEditingController _paymentLinkUrlController =
      TextEditingController();
  bool _showBsbAccountOnInvoice = false;
  bool _showPaymentLinkOnInvoice = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(DaoSystem().get().then((system) {
      _defaultHourlyRateController.money = system!.defaultHourlyRate;
      _defaultCallOutFeeController.money = system.defaultCallOutFee;
      _bsbController.text = system.bsb ?? '';
      _accountNoController.text = system.accountNo ?? '';
      _paymentLinkUrlController.text = system.paymentLinkUrl ?? '';
      _showBsbAccountOnInvoice = system.showBsbAccountOnInvoice ?? true;
      _showPaymentLinkOnInvoice = system.showPaymentLinkOnInvoice ?? true;
      setState(() {});
    }));
  }

  @override
  void dispose() {
    _defaultHourlyRateController.dispose();
    _defaultCallOutFeeController.dispose();
    _bsbController.dispose();
    _accountNoController.dispose();
    _paymentLinkUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system!.defaultHourlyRate =
          MoneyEx.tryParse(_defaultHourlyRateController.text);
      system
        ..defaultCallOutFee =
            MoneyEx.tryParse(_defaultCallOutFeeController.text)
        ..bsb = _bsbController.text
        ..accountNo = _accountNoController.text
        ..paymentLinkUrl = _paymentLinkUrlController.text
        ..showBsbAccountOnInvoice = _showBsbAccountOnInvoice
        ..showPaymentLinkOnInvoice = _showPaymentLinkOnInvoice;

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
          title: const Text('Billing'),
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
                SwitchListTile(
                  title: const Text('Show BSB/Account on Quote/Invoice'),
                  value: _showBsbAccountOnInvoice,
                  onChanged: (value) {
                    setState(() {
                      _showBsbAccountOnInvoice = value;
                    });
                  },
                ),
                HMBTextField(
                  controller: _paymentLinkUrlController,
                  labelText: 'Payment Link URL',
                  keyboardType: TextInputType.url,
                ),
                SwitchListTile(
                  title: const Text('Show Payment Link on Quote/Invoice'),
                  value: _showPaymentLinkOnInvoice,
                  onChanged: (value) {
                    setState(() {
                      _showPaymentLinkOnInvoice = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
}
