import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/parse/parse_customer.dart';
import '../../../util/util.g.dart';
import '../../dialog/source_context.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/widgets.g.dart';
import 'customer_paste_panel.dart';

/// Creates a customer by parsing data from the clipboard
/// looking of elements that identify the customer.
/// The user can also optionally manually enter any element.
class CustomerCreator extends StatefulWidget {
  const CustomerCreator({super.key});

  @override
  State<CustomerCreator> createState() => _CustomerCreatorState();

  static Future<Customer?> show(BuildContext context) async {
    if (context.mounted) {
      return showDialog<Customer>(
        context: context,
        builder: (context) => const CustomerCreator(),
      );
    }
    return null;
  }
}

class _CustomerCreatorState extends State<CustomerCreator> {
  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _surname = TextEditingController();
  final _mobileNo = TextEditingController();
  final _email = TextEditingController();
  final _customerName = TextEditingController();
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _suburb = TextEditingController();
  final _state = TextEditingController();
  final _postcode = TextEditingController();

  @override
  void dispose() {
    _firstName.dispose();
    _surname.dispose();
    _mobileNo.dispose();
    _email.dispose();
    _customerName.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _suburb.dispose();
    _state.dispose();
    _postcode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(6),
    title: const Text('Create Customer'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          children: [
            CustomerPastePanel(onExtract: _onExtract),
            const HMBSpacer(height: true),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  HMBTextField(
                    controller: _customerName,
                    labelText: 'Customer Name',
                    textCapitalization: TextCapitalization.words,
                    required: true,
                  ),
                  HMBTextField(
                    controller: _firstName,
                    labelText: 'First Name',
                    textCapitalization: TextCapitalization.words,
                    required: true,
                  ),
                  HMBTextField(
                    controller: _surname,
                    labelText: 'Surname',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBPhoneField(
                    controller: _mobileNo,
                    labelText: 'Mobile No.',
                    sourceContext: SourceContext(),
                  ),

                  HMBEmailField(controller: _email, labelText: 'Email Address'),
                  HMBTextField(
                    controller: _addressLine1,
                    labelText: 'Address Line 1',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _addressLine2,
                    labelText: 'Address Line 2',
                    textCapitalization: TextCapitalization.words,
                  ),

                  HMBTextField(
                    controller: _suburb,
                    labelText: 'Suburb',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _state,
                    labelText: 'State',
                    textCapitalization: TextCapitalization.words,
                  ),
                  HMBTextField(
                    controller: _postcode,
                    labelText: 'Postcode',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _createEntities,
        child: const Text('Create Customer'),
      ),
    ],
  );

  void _onExtract(ParsedCustomer parsedCustomer) {
    if (parsedCustomer.isEmpty()) {
      HMBToast.info(
        'Unable to extract any customer details from the message. You can copy and paste the details manually.',
      );
      return;
    }

    _email.text = parsedCustomer.email;
    _mobileNo.text = parsedCustomer.mobile;

    _firstName.text = parsedCustomer.firstname;
    _surname.text = parsedCustomer.surname;
    final address = parsedCustomer.address;
    _addressLine1.text = address.street;
    _suburb.text = address.city;
    _state.text = address.state;
    _postcode.text = address.postalCode;

    _customerName.text = '${_firstName.text} ${_surname.text}';

    if (Strings.isBlank(_firstName.text) &&
        Strings.isBlank(_surname.text) &&
        Strings.isBlank(_email.text) &&
        Strings.isBlank(_customerName.text) &&
        Strings.isBlank(_addressLine1.text) &&
        Strings.isBlank(_suburb.text) &&
        Strings.isBlank(_state.text) &&
        Strings.isBlank(_postcode.text)) {}

    setState(() {});
  }

  Future<void> _createEntities() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Build and persist Customer, Contact, and Site objects here
      final system = await DaoSystem().get();

      final customer = Customer.forInsert(
        name: _customerName.text,
        description: '',
        customerType: CustomerType.residential,
        disbarred: false,
        billingContactId: null,
        hourlyRate: system.defaultHourlyRate ?? MoneyEx.zero,
      );
      await DaoCustomer().insert(customer);

      final contact = Contact.forInsert(
        firstName: _firstName.text,
        surname: _surname.text,
        mobileNumber: _mobileNo.text,
        landLine: '',
        officeNumber: '',
        emailAddress: _email.text,
      );

      await DaoContact().insert(contact);

      await DaoContactCustomer().insertJoin(contact, customer);

      /// We only add a site if we have some address details.
      if (!(Strings.isEmpty(_addressLine1.text) &&
          Strings.isEmpty(_addressLine2.text) &&
          Strings.isEmpty(_suburb.text) &&
          Strings.isEmpty(_postcode.text) &&
          Strings.isEmpty(_state.text))) {
        final site = Site.forInsert(
          addressLine1: _addressLine1.text,

          addressLine2: _addressLine2.text,
          suburb: _suburb.text,
          postcode: _postcode.text,
          state: _state.text,
          accessDetails: null,
        );
        await DaoSite().insert(site);

        await DaoSiteCustomer().insertJoin(site, customer);
      }

      final customer2 = customer.copyWith(billingContactId: contact.id);
      await DaoCustomer().update(customer2);

      if (mounted) {
        Navigator.of(context).pop(customer2);
      }
    } catch (error) {
      // Check if the error indicates a duplicate name (unique constraint violation)
      if (error.toString().contains('UNIQUE constraint failed')) {
        HMBToast.error(
          'A Customer with the name ${_customerName.text} already exists.',
        );
      } else {
        HMBToast.error(error.toString());
      }
    }
  }
}
