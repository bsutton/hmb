import '../../../entity/contact.dart';
import '../message_template_dialog.dart';
import 'contact_source.dart';
import 'place_holder.dart';

class ContactName extends PlaceHolder<String, Contact> {
  ContactName({required this.contactSource})
      : super(name: tagName, base: tagbase, source: contactSource);
  final ContactSource contactSource;

  static String tagName = 'contact.name';
  static String tagbase = 'contact';

  @override
  Future<String> value(MessageData data) async =>
      contactSource.value?.firstName ?? '';

  // @override
  // PlaceHolderField<String> field(MessageData data) {
  //   // No field needed; value comes from contactSource
  //   return PlaceHolderField(
  //     placeholder: this,
  //     widget: null,
  //     getValue: (data) async => value(data),
  //   );
  // }

  @override
  void setValue(String? value) {
    // Not used; value comes from contactSource
  }
}
