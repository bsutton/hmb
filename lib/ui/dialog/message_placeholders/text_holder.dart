import '../../../dao/dao_system.dart';
import 'noop_source.dart';
import 'place_holder.dart';
import 'text_source.dart';

/// A default placeholder incase we encounter an unknown
/// placeholder, in which case we just give the user
/// a text field to fill in.
class DefaultHolder extends PlaceHolder<String> {
  DefaultHolder({required super.name})
    : super(
        base: _tagBase,
        source: TextSource(label: name),
      );

  static const _tagBase = 'text';

  @override
  Future<String> value() async => source.value ?? '';
}

class SignatureHolder extends PlaceHolder<String> {
  SignatureHolder() : super(name: tagName, base: tagBase, source: NoopSource());

  // ignore: omit_obvious_property_types
  static String tagName = 'signature';
  // ignore: omit_obvious_property_types
  static String tagBase = 'signature';

  @override
  Future<String> value() => _fetchSignature();

  Future<String> _fetchSignature() async {
    final system = await DaoSystem().get();
    return '''
${system.firstname ?? ''} ${system.surname ?? ''}\n${system.businessName ?? ''}''';
  }
}
