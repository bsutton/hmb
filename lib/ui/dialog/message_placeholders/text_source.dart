/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/material.dart';

import '../source_context.dart';
import 'source.dart';

class TextSource extends Source<String> {
  TextSource({required this.label}) : super(name: 'text');

  final String label;
  final controller = TextEditingController();

  String? text;

  @override
  Widget widget() => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    onChanged: (value) {
      text = value;
      onChanged(value, ResetFields());
    },
  );

  @override
  String? get value => text;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    // NO OP
  }

  @override
  void revise(SourceContext sourceContext) {
    // NO OP
  }
}
