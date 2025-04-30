import '../../../entity/customer.dart';
import 'customer_source.dart';
import 'place_holder.dart';

class CustomerName extends PlaceHolder<Customer> {
  CustomerName({required this.customerSource})
    : super(name: tagName, base: _tagBase, source: customerSource);
  final CustomerSource customerSource;

  // ignore: omit_obvious_property_types
  static String tagName = 'customer.name';
  static const _tagBase = 'customer';

  @override
  Future<String> value() async => customerSource.value?.name ?? '';
}
