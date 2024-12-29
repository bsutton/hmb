import '../../../entity/customer.dart';
import '../message_template_dialog.dart';
import 'customer_source.dart';
import 'place_holder.dart';

class CustomerName extends PlaceHolder<String, Customer> {
  CustomerName({required this.customerSource})
      : super(name: tagName, base: tagBase, source: customerSource);
  final CustomerSource customerSource;

  static String tagName = 'customer.name';
  static String tagBase = 'customer';

  @override
  Future<String> value(MessageData data) async =>
      customerSource.value?.name ?? '';

  // @override
  // PlaceHolderField<String> field(MessageData data) {
  //   // No field needed; value comes from customerSource
  //   return PlaceHolderField(
  //     placeholder: this,
  //     widget: null,
  //     getValue: (data) async => value(data),
  //   );
  // }

  @override
  void setValue(String? value) {
    // Not used; value comes from customerSource
  }
}
