import 'package:strings/strings.dart';

import '../../../util/format.dart';
import '../../../util/local_time.dart';
import '../../hmb_date_time_picker.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class AppointmentTime extends PlaceHolder<LocalTime> {
  AppointmentTime() : super(name: keyName, key: keyScope);

  static String keyName = 'appointment_time';
  static String keyScope = 'appointment_time';

  LocalTime? appointmentTime;
  @override
  Future<String> value(MessageData data) async => formatLocalTime(
      appointmentTime ?? data.appointmentTime ?? LocalTime.now());

  // @override
  // PlaceHolderField<LocalTime> field(MessageData data)
  //=> _buildTimePicker(this);

  @override
  void setValue(LocalTime? value) => appointmentTime = value;
}

/// Date placeholder drop list
PlaceHolderField<LocalTime> _buildTimePicker(
    PlaceHolder<LocalTime> placeholder) {
  final widget = HMBDateTimeField(
    label: placeholder.name.toProperCase(),
    initialDateTime: DateTime.now(),
    onChanged: (datetime) {
      final localTime = LocalTime.fromDateTime(datetime);
      placeholder.setValue(localTime);
      // controller.text = '${datetime.day}/${datetime.month}/${datetime.year}';
      placeholder.onChanged?.call(localTime, ResetFields());
    },
    showDate: false,
  );
  return PlaceHolderField(
      placeholder: placeholder,
      widget: widget,
      getValue: (data) async => placeholder.value(data));
}
