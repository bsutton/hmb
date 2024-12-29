import '../message_template_dialog.dart';
import 'source.dart';

abstract class PlaceHolder<T, S> {
  /// [base] e.g. job
  /// [name] e.g. job.cost
  PlaceHolder({required this.name, required this.base, required this.source});

  // factory PlaceHolder.fromName(String name) {
  //   final placeholder = placeHolders[name];
  //   if (placeholder != null) {
  //     return placeholder.call() as PlaceHolder<T>;
  //   } else {
  //     return DefaultHolder(name) as PlaceHolder<T>;
  //   }
  // }

  String name;

  /// the part of the placeholder name that is used
  /// to get an entity.
  /// e.g. job.name
  /// 'job' is the key.
  final String base;

  Source<S> source;

  Future<String> value(MessageData data);

  void setValue(T? value);
  // PlaceHolderField<T> field(MessageData data);

  /// Used by the field picker to notify the ui
  /// that a new value has been picked.
  void Function(T? data, ResetFields resetFields)? onChanged;

  // ignore: avoid_setters_without_getters
  set listen(void Function(T? onChanged, ResetFields) onChanged) =>
      this.onChanged = onChanged;

  // static Map<String, PlaceHolder<dynamic> Function()> placeHolders = {
  //   AppointmentDate.keyName: AppointmentDate.new,
  //   AppointmentTime.tagName: AppointmentTime.new,
  //   ContactName.keyName: ContactName.new,
  //   CustomerName.keyName: CustomerName.new,
  //   DelayPeriod.keyName: DelayPeriod.new,
  //   DueDate.keyName: DueDate.new,
  //   // JobCost.keyName: JobCost.new,
  //   // JobDescription.keyName: JobDescription.new,
  //   // JobName.keyName: JobName.new,
  //   OriginalDate.keyName: OriginalDate.new,
  //   ServiceDate.keyName: ServiceDate.new,
  //   SiteHolder.tagName: SiteHolder.new,
  //   SignatureHolder.keyName: SignatureHolder.new,
  // };
}

// class PlaceHolderField<T> {
//   PlaceHolderField({
//     required this.placeholder,
//     required this.widget,
//     required this.getValue,
//   });

//   final PlaceHolder<T, S> placeholder;

//   final Widget? widget;
//   final Future<String> Function(MessageData data) getValue;
// }

class ResetFields {
  ResetFields({
    this.contact = false,
    this.customer = false,
    this.job = false,
    this.site = false,
  });
  bool contact;
  bool customer;
  bool job;
  bool site;
}
