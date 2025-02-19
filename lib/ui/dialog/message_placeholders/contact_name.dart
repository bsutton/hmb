import '../../../entity/contact.dart';
import 'contact_source.dart';
import 'place_holder.dart';

class ContactName extends PlaceHolder<Contact> {
  ContactName({required this.contactSource})
    : super(name: tagName, base: tagbase, source: contactSource);
  final ContactSource contactSource;

  static String tagName = 'contact.name';
  static String tagbase = 'contact';

  @override
  Future<String> value() async => contactSource.value?.firstName ?? '';
}
