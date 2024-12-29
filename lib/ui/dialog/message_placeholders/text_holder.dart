import '../../../dao/dao_system.dart';
import '../message_template_dialog.dart';
import 'noop_source.dart';
import 'place_holder.dart';
import 'text_source.dart';

/// A default placeholder incase we encounter an unknown
/// placeholder, in which case we just give the user
/// a text field to fill in.
class DefaultHolder extends PlaceHolder<String, String> {
  DefaultHolder(String name)
      : super(name: name, base: tagBase, source: TextSource(label: name));

  static String tagBase = 'text';

  String? _value;
  @override
  Future<String> value(MessageData data) async => _value ?? '';

  // @override
  // PlaceHolderField<String> field(MessageData data) => _buildTextPicker(this);

  @override
  void setValue(String? value) => _value = value;
}

class SignatureHolder extends PlaceHolder<String, String> {
  SignatureHolder() : super(name: tagName, base: tagBase, source: NoopSource());

  static String tagName = 'signature';
  static String tagBase = 'signature';

  @override
  Future<String> value(MessageData data) async => _fetchSignature();

  @override
  void setValue(String? value) {}

  Future<String> _fetchSignature() async {
    final system = await DaoSystem().get();
    return '''
${system?.firstname ?? ''} ${system?.surname ?? ''}\n${system?.businessName ?? ''}''';
  }
}
