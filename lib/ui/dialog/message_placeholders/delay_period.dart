import '../message_template_dialog.dart';
import 'delay_source.dart';
import 'place_holder.dart';

class DelayPeriod extends PlaceHolder<String, String> {
  DelayPeriod(this.delaySource) : super(name: tagName, base: tagBase, source: delaySource);

  static String tagName = 'delay_period';
  static String tagBase = 'delay_period';

  final DelaySource delaySource;

  String? delayPeriod;

  @override
  void setValue(String? value) {
    delayPeriod = value;
  }

  @override
  Future<String> value(MessageData data) async => delayPeriod ?? '';
}
