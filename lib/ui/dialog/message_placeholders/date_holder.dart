/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// ignore_for_file: omit_obvious_property_types

import '../../../util/format.dart';
import '../../../util/local_date.dart';
import 'date_source.dart';
import 'place_holder.dart';

class ServiceDate extends PlaceHolder<LocalDate> {
  static String tagName = 'date.service';
  static const _tagBase = 'date.service';

  static String label = 'Service Date';

  final DateSource dateSource;

  ServiceDate({required this.dateSource})
    : super(name: tagName, base: _tagBase, source: dateSource);

  @override
  Future<String> value() async => formatLocalDate(dateSource.date!);
}

class DueDate extends PlaceHolder<LocalDate> {
  static String tagName = 'invoice.due_date';
  static const _tagBase = 'invoice.due_date';
  static String label = 'Due Date';

  final DateSource dateSource;

  DueDate({required this.dateSource})
    : super(name: tagName, base: _tagBase, source: dateSource);

  @override
  Future<String> value() async =>
      formatLocalDate(dateSource.date ?? LocalDate.today());
}
