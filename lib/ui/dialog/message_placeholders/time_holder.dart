import '../../../util/format.dart';
import '../../../util/local_time.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';
import 'time_source.dart';

class AppointmentTime extends PlaceHolder<LocalTime, LocalTime> {
  AppointmentTime(this.timeSource)
      : super(name: tagName, base: tagBase, source: TimeSource(label));

  static String tagName = 'appointment_time';
  static String tagBase = 'appointment_time';
  static String label = 'Appointment Time';

  final TimeSource timeSource;

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
