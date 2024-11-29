import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_system.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

/// A default placeholder incase we encounter an unknown
/// placeholder, in which case we just give the user
/// a text field to fill in.
class DefaultHolder extends PlaceHolder<String> {
  DefaultHolder(String name) : super(name: name, key: keyScope);

  static String keyScope = 'text';

  String? _value;
  @override
  Future<String> value(MessageData data) async => _value ?? '';

  // @override
  // PlaceHolderField<String> field(MessageData data) => _buildTextPicker(this);

  @override
  void setValue(String? value) => _value = value;

}

/// Date placeholder drop list
PlaceHolderField<String> _buildTextPicker(DefaultHolder placeholder) {
  final controller = TextEditingController();
  final widget = TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: placeholder.name.toCapitalised()),
    onChanged: (value) {
      placeholder._value = value;
      placeholder.onChanged?.call(value, ResetFields());
    },
  );

  return PlaceHolderField(
      placeholder: placeholder,
      widget: widget,
      getValue: (data) async => placeholder.value(data));
}

class SignatureHolder extends PlaceHolder<String> {
  SignatureHolder() : super(name: keyName, key: keyScope);

  static String keyName = 'signature';
  static String keyScope = 'signature';

  @override
  Future<String> value(MessageData data) async => _fetchSignature();

  // @override
  // PlaceHolderField<String> field(MessageData data) =>
  //      PlaceHolderField(
  //     placeholder: this,
  //     widget: null,
  //     getValue: (data) async => value(data));

  @override
  void setValue(String? value) {}


  Future<String> _fetchSignature() async {
    final system = await DaoSystem().get();
    return '''
${system?.firstname ?? ''} ${system?.surname ?? ''}\n${system?.businessName ?? ''}''';
  }
}
