import '../../../dao/dao_contact.dart';
import '../../../dao/dao_customer.dart';
import '../../../entity/contact.dart';
import '../../select/hmb_droplist.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class ContactName extends PlaceHolder<Contact> {
  ContactName() : super(name: keyName, key: keyScope);

  static String keyName = 'contact';
  static String keyScope = 'job';

  Contact? contact;
  @override
  Future<String> value(MessageData data) async => contact?.fullname ?? '';

  @override
  PlaceHolderField<Contact> field(MessageData data) =>
      _buildContactDroplist(this, data);

  @override
  void setValue(Contact? value) => contact = value;
}

/// Contact placeholder drop list
PlaceHolderField<Contact> _buildContactDroplist(
    ContactName placeholder, MessageData data) {
  placeholder.setValue(data.contact);

  final widget = HMBDroplist<Contact>(
    title: 'Contact',
    selectedItem: () async => placeholder.contact,
    items: (filter) async {
      if (data.job != null && data.job!.contactId != null) {
        final contact = await DaoContact().getById(data.job!.contactId);
        return [contact!];
      } else {
        final customer = await DaoCustomer().getById(data.job!.customerId);
        return DaoContact().getByFilter(customer!, filter);
      }
    },
    format: (contact) => contact.fullname,
    onChanged: (contact) {
      placeholder.contact = contact;
      // Reset site and contact when contact changes
      assert(placeholder.onChanged != null, 'You must call listen');
      placeholder.onChanged
          ?.call(contact, ResetFields(site: true, contact: true));
    },
  );
  return PlaceHolderField(
      placeholder: placeholder,
      widget: widget,
      getValue: (data) async => placeholder.value(data));
}
