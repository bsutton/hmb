import '../../../entity/contact.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class ContactName extends PlaceHolder<Contact> {
  ContactName() : super(name: keyName, key: keyScope);

  static String keyName = 'contact';
  static String keyScope = 'contact';

  Contact? contact;
  @override
  Future<String> value(MessageData data) async => contact?.fullname ?? '';

  // @override
  // PlaceHolderField<Contact> field(MessageData data) =>
  //     _buildContactDroplist(this, data);

  @override
  void setValue(Contact? value) => contact = value;
}
