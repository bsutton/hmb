/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

enum ReceiptLineMatchStatus {
  unmatched('unmatched', 'Unmatched'),
  matched('matched', 'Matched'),
  deferred('deferred', 'Deferred'),
  notJobRelated('not_job_related', 'Not Job Related');

  const ReceiptLineMatchStatus(this.code, this.label);

  final String code;
  final String label;

  static ReceiptLineMatchStatus fromCode(
    String? code, {
    int? matchedTaskItemId,
  }) {
    if (matchedTaskItemId != null && code == null) {
      return ReceiptLineMatchStatus.matched;
    }
    return ReceiptLineMatchStatus.values.firstWhere(
      (status) => status.code == code,
      orElse: () => ReceiptLineMatchStatus.unmatched,
    );
  }
}
