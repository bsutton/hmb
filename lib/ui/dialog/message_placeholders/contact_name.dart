import '../../../entity/contact.dart';
import 'contact_source.dart';
import 'place_holder.dart';

class ContactName extends PlaceHolder<Contact> {
  ContactName({required this.contactSource})
    : super(name: tagName, base: _tagbase, source: contactSource);
  final ContactSource contactSource;

  // ignore: omit_obvious_property_types
  static String tagName = 'contact.name';
  static const _tagbase = 'contact';

  @override
  Future<String> value() async => contactSource.value?.firstName ?? '';
}
