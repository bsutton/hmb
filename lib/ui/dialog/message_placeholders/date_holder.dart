// ignore_for_file: omit_obvious_property_types

import '../../../util/format.dart';
import '../../../util/local_date.dart';
import 'date_source.dart';
import 'place_holder.dart';

class ServiceDate extends PlaceHolder<LocalDate> {
  ServiceDate({required this.dateSource})
    : super(name: tagName, base: _tagBase, source: dateSource);

  static String tagName = 'date.service';
  static const _tagBase = 'date.service';

  static String label = 'Service Date';

  final DateSource dateSource;

  @override
  Future<String> value() async => formatLocalDate(dateSource.date!);
}

class DueDate extends PlaceHolder<LocalDate> {
  DueDate({required this.dateSource})
    : super(name: tagName, base: _tagBase, source: dateSource);

  static String tagName = 'invoice.due_date';
  static const _tagBase = 'invoice.due_date';
  static String label = 'Due Date';

  final DateSource dateSource;

  @override
  Future<String> value() async =>
      formatLocalDate(dateSource.date ?? LocalDate.today());
}
