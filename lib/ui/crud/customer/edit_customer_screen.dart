import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_site.dart';
import '../../../entity/entity.g.dart';
import '../../../util/money_ex.dart';
import '../../../util/platform_ex.dart';
import '../../widgets/fields/hmb_name_field.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/hbm_crud_contact.dart';
import '../../widgets/hmb_crud_site.dart';
import '../../widgets/hmb_switch.dart';
import '../../widgets/layout/hmb_form_section.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/select/hmb_select_contact.dart';
import '../base_full_screen/edit_entity_screen.dart';
import '../base_nested/list_nested_screen.dart';

class CustomerEditScreen extends StatefulWidget {
  const CustomerEditScreen({super.key, this.customer});
  final Customer? customer;

  @override
  // ignore: library_private_types_in_public_api
  _CustomerEditScreenState createState() => _CustomerEditScreenState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Customer?>('customer', customer));
  }
}

class _CustomerEditScreenState extends DeferredState<CustomerEditScreen>
    implements EntityState<Customer> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _hourlyRateController;
  late bool _disbarred;
  late CustomerType _selectedCustomerType;

  @override
  Customer? currentEntity;

  @override
  void initState() {
    super.initState();

    currentEntity ??= widget.customer;
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.customer?.description ?? '',
    );
    _hourlyRateController = TextEditingController(
      text: widget.customer?.hourlyRate.amount.toString() ?? '0.00',
    );
    _disbarred = widget.customer?.disbarred ?? false;
    _selectedCustomerType =
        widget.customer?.customerType ?? CustomerType.residential;
  }

  @override
  Future<void> asyncInitState() async {
    final billingContact = await DaoContact().getById(
      widget.customer?.billingContactId,
    );
    // Set the billing contact only once during init
    June.getState(CustomerBillingContact.new).contact = billingContact;

    if (widget.customer == null) {
      // ignore: discarded_futures
      final system = await DaoSystem().get();
      setState(() {
        _hourlyRateController.text =
            system.defaultHourlyRate?.amount.toString() ?? '0.00';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<Customer>(
    entityName: 'Customer',
    dao: DaoCustomer(),
    entityState: this,
    editor: (customer, {required isNew}) => DeferredBuilder(
      this,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBFormSection(
            children: [
              Text(
                'Customer Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              HMBNameField(
                autofocus: isNotMobile,
                controller: _nameController,
                labelText: 'Name',
                required: true,
                keyboardType: TextInputType.name,
              ),
              HMBTextArea(
                controller: _descriptionController,
                labelText: 'Description',
              ),
              HMBTextField(
                controller: _hourlyRateController,
                labelText: 'Hourly Rate',
                keyboardType: TextInputType.number,
                required: true,
              ),
              HMBSwitch(
                labelText: 'Disbarred',
                initialValue: _disbarred,
                onChanged: (value) {
                  setState(() => _disbarred = value);
                },
              ),
              HMBDroplist<CustomerType>(
                selectedItem: () async => _selectedCustomerType,
                items: (filter) async => CustomerType.values,
                title: 'Customer Type',
                onChanged: (newValue) {
                  _selectedCustomerType = newValue!;
                },
                format: (item) => item.display,
              ),

              // Select billing contact
              JuneBuilder<CustomerBillingContact>(
                CustomerBillingContact.new,
                builder: (billingContactState) => HMBSelectContact(
                  title: 'Billing Contact',
                  initialContact: billingContactState.contact?.id,
                  customer: customer,
                  onSelected: (contact) {
                    if (contact != null) {
                      billingContactState
                        ..contact = contact
                        ..setState();
                    }
                  },
                ),
              ),
            ],
          ),
          HMBCrudContact<Customer>(
            parentTitle: 'Customer',
            parent: Parent(customer),
            daoJoin: JoinAdaptorCustomerContact(),
          ),
          HBMCrudSite(
            parentTitle: 'Customer',
            parent: Parent(customer),
            daoJoin: JoinAdaptorCustomerSite(),
          ),
        ],
      ),
    ),
  );

  @override
  Future<Customer> forUpdate(Customer customer) async => Customer.forUpdate(
    entity: customer,
    name: _nameController.text,
    description: _descriptionController.text,
    disbarred: _disbarred,
    customerType: _selectedCustomerType,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    billingContactId: June.getState(CustomerBillingContact.new).contact?.id,
  );

  @override
  Future<Customer> forInsert() async => Customer.forInsert(
    name: _nameController.text,
    description: _descriptionController.text,
    disbarred: _disbarred,
    customerType: _selectedCustomerType,
    hourlyRate: MoneyEx.tryParse(_hourlyRateController.text),
    billingContactId: June.getState(CustomerBillingContact.new).contact?.id,
  );

  @override
  Future<void> saved() async {
    setState(() {});
  }
}

class CustomerBillingContact extends JuneState {
  CustomerBillingContact();

  Contact? contact;
}
