import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // Import color picker
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' hide context;
import 'package:path_provider/path_provider.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_system.dart';
import '../../entity/system.dart';
import '../../util/money_ex.dart';
import '../../widgets/hmb_droplist.dart';
import '../../widgets/hmb_money_editing_controller.dart';
import '../../widgets/hmb_money_field.dart';
import '../../widgets/hmb_text_field.dart';
import '../../widgets/hmb_text_themes.dart';
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
  late final HMBMoneyEditingController _defaultBookingFeeController =
      HMBMoneyEditingController();
  late final TextEditingController _bsbController = TextEditingController();
  late final TextEditingController _accountNoController =
      TextEditingController();
  late final TextEditingController _paymentLinkUrlController =
      TextEditingController();
  late final TextEditingController _logoPathController =
      TextEditingController();
  bool _showBsbAccountOnInvoice = false;
  bool _showPaymentLinkOnInvoice = false;
  LogoAspectRatio _logoAspectRatio = LogoAspectRatio.square;
  String? _logoFile;
  Color _billingColour = Colors.deepPurpleAccent; // Default billing color

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    unawaited(DaoSystem().get().then((system) {
      _defaultHourlyRateController.money = system!.defaultHourlyRate;
      _defaultBookingFeeController.money = system.defaultBookingFee;
      _logoFile = system.logoPath;
      _logoAspectRatio = system.logoAspectRatio;
      _bsbController.text = system.bsb ?? '';
      _accountNoController.text = system.accountNo ?? '';
      _paymentLinkUrlController.text = system.paymentLinkUrl ?? '';
      _logoPathController.text = system.logoPath;
      _logoAspectRatio = system.logoAspectRatio;
      _billingColour = Color(system.billingColour);
      _showBsbAccountOnInvoice = system.showBsbAccountOnInvoice ?? true;
      _showPaymentLinkOnInvoice = system.showPaymentLinkOnInvoice ?? true;
      setState(() {});
    }));
  }

  @override
  void dispose() {
    _defaultHourlyRateController.dispose();
    _defaultBookingFeeController.dispose();
    _bsbController.dispose();
    _accountNoController.dispose();
    _paymentLinkUrlController.dispose();
    _logoPathController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      final system = await DaoSystem().get();
      // Save the form data
      system!.defaultHourlyRate =
          MoneyEx.tryParse(_defaultHourlyRateController.text);
      system
        ..defaultBookingFee =
            MoneyEx.tryParse(_defaultBookingFeeController.text)
        ..bsb = _bsbController.text
        ..accountNo = _accountNoController.text
        ..paymentLinkUrl = _paymentLinkUrlController.text
        ..showBsbAccountOnInvoice = _showBsbAccountOnInvoice
        ..showPaymentLinkOnInvoice = _showPaymentLinkOnInvoice
        ..logoPath = _logoPathController.text
        ..logoAspectRatio = _logoAspectRatio
        ..billingColour = _billingColour.value; // Save billing color

      await DaoSystem().update(system);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      HMBToast.error('Fix the errors and try again.');
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
          TextButton(
            child: const Text('Select'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
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
            child: ListView(children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      controller: _bsbController,
                      labelText: 'BSB',
                      keyboardType: TextInputType.number),
                  HMBTextField(
                    controller: _accountNoController,
                    labelText: 'Account Number',
                    keyboardType: TextInputType.number,
                  ),
                  const HMBTextHeadline2('Formatting for Invoices and Quotes'),
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
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Logo'),
                    onPressed: _pickLogo,
                  ),
                  if (Strings.isNotBlank(_logoFile)) ...[
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
                  ),
                ],
              ),
            ]),
          ),
        ),
      );
}
