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

class DelaySource extends Source<String> {
  DelaySource() : super(name: 'delay');

  String delay = periods[0];

  static const periods = <String>[
    '10 minutes',
    '15 minutes',
    '20 minutes',
    '30 minutes',
    '45 minutes',
    '1 hour',
    '1.5 hours',
    '2 hours',
  ];

  /// Delay Period placeholder drop list
  @override
  Widget widget() => DropdownButtonFormField<String>(
    decoration: const InputDecoration(labelText: 'Delay Period'),
    initialValue: periods[0],
    items: periods
        .map(
          (period) =>
              DropdownMenuItem<String>(value: period, child: Text(period)),
        )
        .toList(),
    onChanged: (newValue) {
      delay = newValue ?? '';
    },
  );

  @override
  String? get value => delay;

  @override
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext) {
    // noop
  }

  @override
  void revise(SourceContext sourceContext) {
    sourceContext.delayPeriod = delay;
  }
}
