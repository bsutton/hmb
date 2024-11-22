import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';

class ServiceDate extends PlaceHolder<LocalDate> {
  ServiceDate() : super(name: keyName, key: keyScope);

  static String keyName = 'service_date';
  static String keyScope = 'service_date';

  LocalDate? serviceDate;

  @override
  Future<String> value(MessageData data) async => formatLocalDate(serviceDate!);

// @override
//   PlaceHolderField<LocalDate> field(MessageData data)
//=> _buildDatePicker(this);

  @override
  void setValue(LocalDate? value) => serviceDate = value;
}

class OriginalDate extends PlaceHolder<LocalDate> {
  OriginalDate() : super(name: keyName, key: keyScope);

  static String keyName = 'original_date';
  static String keyScope = 'original_date';
  LocalDate? originalDate;

  @override
  Future<String> value(MessageData data) async =>
      formatLocalDate(data.originalDate!);

  // @override
  // PlaceHolderField<LocalDate> field(MessageData data)
  // => _buildDatePicker(this);

  @override
  void setValue(LocalDate? value) => originalDate = value;
}

class AppointmentDate extends PlaceHolder<LocalDate> {
  AppointmentDate() : super(name: keyName, key: keyScope);

  static String keyName = 'appointment_date';
  static String keyScope = 'appointment_date';

  LocalDate? appointmentDate;
  @override
  Future<String> value(MessageData data) async =>
      formatLocalDate(data.appointmentDate ?? LocalDate.today());

  // @override
  // PlaceHolderField<LocalDate> field(MessageData data)
  //=> _buildDatePicker(this);

  @override
  void setValue(LocalDate? value) => appointmentDate = value;
}

class DueDate extends PlaceHolder<LocalDate> {
  DueDate() : super(name: keyName, key: keyScope);

  static String keyName = 'invoice.due_date';
  static String keyScope = 'invoice.due_date';

  LocalDate? dueDate;
  @override
  Future<String> value(MessageData data) async =>
      formatLocalDate(data.invoice?.dueDate ?? LocalDate.today());

  // @override
  // PlaceHolderField<LocalDate> field(MessageData data) =>
  //     throw UnimplementedError();

  @override
  void setValue(LocalDate? value) => dueDate = value;
}

/// Date placeholder drop list
// PlaceHolderField<LocalDate> _buildDatePicker(
//     PlaceHolder<LocalDate> placeholder) {
//   final widget = HMBDateTimeField(
//     label: placeholder.name.toProperCase(),
//     initialDateTime: DateTime.now(),
//     onChanged: (datetime) {
//       final localDate = LocalDate.fromDateTime(datetime);
//       placeholder.setValue(localDate);
//       // controller.text = '${datetime.day}/${datetime.month}/${datetime.year}';
//       placeholder.onChanged?.call(localDate, ResetFields());
//     },
//     showTime: false,
//   );
//   return PlaceHolderField(
//       placeholder: placeholder,
//       widget: widget,
//       getValue: (data) async => placeholder.value(data));
// }
