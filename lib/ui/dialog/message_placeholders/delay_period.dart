import 'delay_source.dart';
import 'place_holder.dart';

class DelayPeriod extends PlaceHolder<String> {
  DelayPeriod({required this.delaySource})
      : super(name: tagName, base: tagBase, source: delaySource);

  static String tagName = 'delay_period';
  static String tagBase = 'delay_period';

  final DelaySource delaySource;

  @override
  Future<String> value() async => delaySource.delay;
}
