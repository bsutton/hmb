import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Import color picker
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' hide context;
import 'package:path_provider/path_provider.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_system.dart';
import '../../../entity/system.dart';
import '../../../util/app_title.dart';
import '../../../util/money_ex.dart';
import '../../../util/uri_ex.dart';
import '../../widgets/color_ex.dart';
import '../../widgets/fields/hmb_money_editing_controller.dart';
import '../../widgets/fields/hmb_money_field.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/help_button.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/save_and_close.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/text/hmb_text_themes.dart';

class SystemBillingScreen extends StatefulWidget {
  const SystemBillingScreen({super.key, this.showButtons = true});

  final bool showButtons;

  @override
  // ignore: library_private_types_in_public_api
  SystemBillingScreenState createState() => SystemBillingScreenState();
}

class SystemBillingScreenState extends DeferredState<SystemBillingScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _defaultHourlyRateController = HMBMoneyEditingController();
  late final _defaultBookingFeeController = HMBMoneyEditingController();
  late final _bsbController = TextEditingController();
  late final _accountNoController = TextEditingController();
  late final _paymentLinkUrlController = TextEditingController();
  late TextEditingController _paymentTermsInDaysController;
  late TextEditingController _paymentOptionsController;

  late final _logoPathController = TextEditingController();
  var _showBsbAccountOnInvoice = false;
  var _showPaymentLinkOnInvoice = false;
  LogoAspectRatio _logoAspectRatio = LogoAspectRatio.square;
  String? _logoFile;
  Color _billingColour = Colors.deepPurpleAccent; // Default billing color

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Billing');
    final system = await DaoSystem().get();
    _defaultHourlyRateController.money = system.defaultHourlyRate;
    _defaultBookingFeeController.money = system.defaultBookingFee;
    _logoFile = system.logoPath;
    _logoAspectRatio = system.logoAspectRatio;
    _bsbController.text = system.bsb ?? '';
    _accountNoController.text = system.accountNo ?? '';
    _paymentLinkUrlController.text = system.paymentLinkUrl ?? '';
    _paymentTermsInDaysController = TextEditingController(
      text: system.paymentTermsInDays.toString(),
    );
    _paymentOptionsController = TextEditingController(
      text: system.paymentOptions,
    );

    _logoPathController.text = system.logoPath;
    _logoAspectRatio = system.logoAspectRatio;
    _billingColour = Color(system.billingColour);
    _showBsbAccountOnInvoice = system.showBsbAccountOnInvoice ?? true;
    _showPaymentLinkOnInvoice = system.showPaymentLinkOnInvoice ?? true;
  }

  @override
  void dispose() {
    _defaultHourlyRateController.dispose();
    _defaultBookingFeeController.dispose();
    _bsbController.dispose();
    _accountNoController.dispose();

    _paymentLinkUrlController.dispose();
    _paymentTermsInDaysController.dispose();
    _paymentOptionsController.dispose();

    _logoPathController.dispose();
    super.dispose();
  }

  Future<bool> save({required bool close}) async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system
        ..defaultHourlyRate = MoneyEx.tryParse(
          _defaultHourlyRateController.text,
        )
        ..defaultBookingFee = MoneyEx.tryParse(
          _defaultBookingFeeController.text,
        )
        ..bsb = _bsbController.text
        ..accountNo = _accountNoController.text
        ..paymentLinkUrl = _paymentLinkUrlController.text
        ..showBsbAccountOnInvoice = _showBsbAccountOnInvoice
        ..showPaymentLinkOnInvoice = _showPaymentLinkOnInvoice
        ..preferredUnitSystem = system.preferredUnitSystem
        ..paymentTermsInDays =
            int.tryParse(_paymentTermsInDaysController.text) ?? 3
        ..paymentOptions = _paymentOptionsController.text
        ..logoPath = _logoPathController.text
        ..logoAspectRatio = _logoAspectRatio
        ..billingColour = _billingColour.toColorValue(); // Save billing color

      await DaoSystem().update(system);

      if (mounted) {
        HMBToast.info('saved');
        if (close) {
          context.go('/dashboard/settings');
        }
      }
      return true;
    } else {
      HMBToast.error('Fix the errors and try again.');
      return false;
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      await _saveLogoFile(pickedFile.path);
      setState(() {
        _logoFile = pickedFile.path;
        _logoPathController.text = pickedFile.path;
      });
    }
  }

  Future<void> _saveLogoFile(String path) async {
    final directory = await getApplicationDocumentsDirectory();
    final logoPath = join(directory.path, 'logo', basename(path));
    if (!exists(dirname(logoPath))) {
      createDir(dirname(logoPath), recursive: true);
    }
    copy(path, logoPath, overwrite: true);
  }

  Future<void> _pickBillingColour() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Billing Colour'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _billingColour,
            onColorChanged: (color) {
              setState(() {
                _billingColour = color;
              });
            },
          ),
        ),
        actions: [
          HMBButton(
            label: 'Select',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
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

  Widget _buildForm() => DeferredBuilder(
    this,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HMBMoneyField(
              controller: _defaultHourlyRateController,
              labelText: 'Default Hourly Rate',
              fieldName: 'default hourly rate',
            ),
            HelpWrapper(
              title: 'What is the Booking Fee',
              tooltip: 'Booking Fee',
              helpText: '''
The booking fee can be applied as a surcharge to each Job.
Sometime this is referred to as a Surcharge, Callout Fee or Admin Fee''',
              child: HMBMoneyField(
                controller: _defaultBookingFeeController,
                labelText: 'Default Booking Fee',
                fieldName: 'default Booking Fee',
              ),
            ),
            HMBTextField(
              controller: _bsbController,
              labelText: 'BSB',
              keyboardType: TextInputType.number,
            ).help('BSB', '''
Enter the Bank State Branch (BSB) for your bank account 
where customers will deposit payments.
The BSB will appear on Invoices.'''),
            HMBTextField(
              controller: _accountNoController,
              labelText: 'Account Number',
              keyboardType: TextInputType.number,
            ).help('BSB', '''
Your bank account no. where customers will deposit payments.
The account no. will appear on invoices'''),
            HMBTextField(
              controller: _paymentTermsInDaysController,
              labelText: 'Payment Terms (in Days)',
              keyboardType: TextInputType.number,
            ).help('Payment Terms', '''
Used to calculate the due date on invoices.
The due date will be calculated as Today plus the enter Payment Terms'''),
            HMBTextArea(
              controller: _paymentOptionsController,
              labelText: 'Payment Options',
            ).help('Payment Options', '''
Appears on your invoice
and can be use to communicate information to your customer on how to make a payment
and what forms of payment you accept.'''),
            const HMBTextHeadline2('Invoices and Quotes'),
            SwitchListTile(
              title: const Text('Show BSB/Account'),
              value: _showBsbAccountOnInvoice,
              onChanged: (value) {
                setState(() {
                  _showBsbAccountOnInvoice = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Show Payment Link'),
              value: _showPaymentLinkOnInvoice,
              onChanged: (value) {
                setState(() {
                  _showPaymentLinkOnInvoice = value;
                });
              },
            ),
            if (_showPaymentLinkOnInvoice)
              HMBTextField(
                controller: _paymentLinkUrlController,
                labelText: 'Payment Link URL',
                keyboardType: TextInputType.url,
                validator: (value) => !UriEx.isValid(value)
                    ? 'Payment link must be a valid URL'
                    : null,
              ).help(
                'Payment Link',
                'A link to details on how the user can pay. Appears on Invoices and Quotes. e.g. https://mysite/payment.html',
              ),
            const SizedBox(height: 20),
            HMBDroplist<LogoAspectRatio>(
              title: 'Logo Aspect Ratio',
              selectedItem: () async => _logoAspectRatio,
              items: (filter) async => LogoAspectRatio.values,
              format: (logoType) => logoType.name,
              onChanged: (value) {
                setState(() {
                  _logoAspectRatio = value ?? LogoAspectRatio.square;
                });
              },
            ).help('Logo Aspect Ration', '''
The shape of your Logo. Your logo will appear on Invoices and Quotes.'''),
            const SizedBox(height: 20),
            HMBButton.withIcon(
              label: 'Upload Logo',
              icon: const Icon(Icons.upload_file),
              onPressed: _pickLogo,
            ),
            if (Strings.isNotBlank(_logoFile) && exists(_logoFile!)) ...[
              const SizedBox(height: 10),
              Image.file(
                File(_logoFile!),
                width: _logoAspectRatio.width.toDouble(),
                height: _logoAspectRatio.height.toDouble(),
              ),
            ],
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Billing Colour'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _billingColour,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(),
                ),
              ),
              onTap: _pickBillingColour,
            ).help('Billing Colour', '''
The colour theme that will be used on you Invoices and Quotes.'''),
          ],
        ),
      ),
    ),
  );
}
