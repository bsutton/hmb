import '../../../util/format.dart';
import '../../../util/local_date.dart';
import '../message_template_dialog.dart';
import 'date_source.dart';
import 'place_holder.dart';

class ServiceDate extends PlaceHolder<LocalDate, LocalDate> {
  ServiceDate(this.dateSource)
      : super(name: tagName, base: tagBase, source: dateSource);

  static String tagName = 'service_date';
  static String tagBase = 'service_date';

  static String label = 'Service Date';

  final DateSource dateSource;

  LocalDate? serviceDate;

  @override
  Future<String> value(MessageData data) async => formatLocalDate(serviceDate!);

// @override
//   PlaceHolderField<LocalDate> field(MessageData data)
//=> _buildDatePicker(this);

  @override
  void setValue(LocalDate? value) => serviceDate = value;
}

class OriginalDate extends PlaceHolder<LocalDate, LocalDate> {
  OriginalDate(this.dateSource)
      : super(name: tagName, base: tagBase, source: dateSource);

  static String tagName = 'original_date';
  static String tagBase = 'original_date';
  static String label = 'Original Date';

  LocalDate? originalDate;

  DateSource dateSource;

  @override
  Future<String> value(MessageData data) async =>
      formatLocalDate(data.originalDate!);

  // @override
  // PlaceHolderField<LocalDate> field(MessageData data)
  // => _buildDatePicker(this);

  @override
  void setValue(LocalDate? value) => originalDate = value;
}

class AppointmentDate extends PlaceHolder<LocalDate, LocalDate> {
  AppointmentDate(this.dateSource)
      : super(name: tagName, base: tagBase, source: dateSource);

  static String tagName = 'appointment.date';
  static String tagBase = 'appointment.date';

  final DateSource dateSource;
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

class DueDate extends PlaceHolder<LocalDate, LocalDate> {
  DueDate(this.dateSource)
      : super(name: tagName, base: tagBase, source: dateSource);

  static String tagName = 'invoice.due_date';
  static String tagBase = 'invoice.due_date';
  static String label = 'Due Date';

  final DateSource dateSource;

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
