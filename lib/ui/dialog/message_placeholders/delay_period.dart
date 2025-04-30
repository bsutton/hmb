import 'delay_source.dart';
import 'place_holder.dart';

class DelayPeriod extends PlaceHolder<String> {
  DelayPeriod({required this.delaySource})
    : super(name: tagName, base: _tagBase, source: delaySource);

  // ignore: omit_obvious_property_types
  static String tagName = 'delay_period';
  static const _tagBase = 'delay_period';

  final DelaySource delaySource;

  @override
  Future<String> value() async => delaySource.delay;
}
