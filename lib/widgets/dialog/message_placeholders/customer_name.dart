import '../message_template_dialog.dart';
import 'customer_source.dart';
import 'place_holder.dart';

class CustomerName extends PlaceHolder<String> {
  final CustomerSource customerSource;

  CustomerName({required this.customerSource}) : super(name: 'customer.name', key: 'customer');

  @override
  Future<String> value(MessageData data) async {
    return customerSource.value?.name ?? '';
  }

  @override
  PlaceHolderField<String> field(MessageData data) {
    // No field needed; value comes from customerSource
    return PlaceHolderField(
      placeholder: this,
      widget: null,
      getValue: (data) async => value(data),
    );
  }

  @override
  void setValue(String? value) {
    // Not used; value comes from customerSource
  }
}
