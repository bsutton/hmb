import '../../../dao/dao_customer.dart';
import '../../../entity/customer.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class CustomerName extends PlaceHolder<Customer> {
  CustomerName() : super(name: keyName, key: keyScope);

  static String keyName = 'customer.name';
  static String keyScope = 'customer';

  Customer? customer;
  @override
  Future<String> value(MessageData data) async => customer?.name ?? '';

  // @override
  // PlaceHolderField<Customer> field(MessageData data) =>
  //     _buildCustomerDroplist(this, data);

  @override
  void setValue(Customer? value) => customer = value;
}

/// Customer placeholder drop list
PlaceHolderField<Customer> _buildCustomerDroplist(
    CustomerName placeholder, MessageData data) {
  placeholder.setValue(data.customer);

  final widget = HMBDroplist<Customer>(
    title: 'Customer',
    selectedItem: () async => placeholder.customer,
    items: (filter) async => DaoCustomer().getByFilter(filter),
    format: (customer) => customer.name,
    onChanged: (customer) {
      placeholder.customer = customer;
      // Reset site and contact when customer changes
      placeholder.onChanged
          ?.call(customer, ResetFields(site: true, contact: true));
    },
  );
  return PlaceHolderField(
      placeholder: placeholder,
      widget: widget,
      getValue: (data) async => placeholder.value(data));
}
