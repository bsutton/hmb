import '../../../entity/customer.dart';
import 'customer_source.dart';
import 'place_holder.dart';

class CustomerName extends PlaceHolder<Customer> {
  CustomerName({required this.customerSource})
    : super(name: tagName, base: tagBase, source: customerSource);
  final CustomerSource customerSource;

  static String tagName = 'customer.name';
  static String tagBase = 'customer';

  @override
  Future<String> value() async => customerSource.value?.name ?? '';
}
