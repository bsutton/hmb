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

import '../../api/external_accounting.dart';

const standardPaymentMethods = [
  'Bank transfer',
  'Card',
  'Cash',
  'Cheque',
  'Osko/PayID',
];
const otherPaymentMethod = 'Other';

Future<List<String>> loadPaymentMethodOptions() async {
  final integrationPaymentMethod = await ExternalAccounting().displayName();
  return [
    ...standardPaymentMethods,
    if (integrationPaymentMethod != null) integrationPaymentMethod,
    otherPaymentMethod,
  ];
}

String? selectedPaymentMethod(String method, String otherMethod) {
  if (method == otherPaymentMethod) {
    final trimmed = otherMethod.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return method;
}
