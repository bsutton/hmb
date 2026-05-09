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

import 'entity.dart';

class TaxScheme extends Entity<TaxScheme> {
  final String countryCode;
  final String code;
  final String displayName;
  final String taxLabel;
  final bool supportsInputCredits;
  final bool supportsJurisdictionReporting;

  TaxScheme({
    required super.id,
    required this.countryCode,
    required this.code,
    required this.displayName,
    required this.taxLabel,
    required this.supportsInputCredits,
    required this.supportsJurisdictionReporting,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  TaxScheme.forInsert({
    required this.countryCode,
    required this.code,
    required this.displayName,
    required this.taxLabel,
    required this.supportsInputCredits,
    required this.supportsJurisdictionReporting,
  }) : super.forInsert();

  factory TaxScheme.fromMap(Map<String, dynamic> map) => TaxScheme(
    id: map['id'] as int,
    countryCode: map['country_code'] as String,
    code: map['code'] as String,
    displayName: map['display_name'] as String,
    taxLabel: map['tax_label'] as String,
    supportsInputCredits: (map['supports_input_credits'] as int? ?? 1) == 1,
    supportsJurisdictionReporting:
        (map['supports_jurisdiction_reporting'] as int? ?? 0) == 1,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'country_code': countryCode,
    'code': code,
    'display_name': displayName,
    'tax_label': taxLabel,
    'supports_input_credits': supportsInputCredits ? 1 : 0,
    'supports_jurisdiction_reporting': supportsJurisdictionReporting ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
