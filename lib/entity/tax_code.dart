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

enum TaxTreatment {
  taxable,
  zeroRated,
  exempt,
  outOfScope,
  reverseCharge,
  import,
  manual;

  String get storageValue => switch (this) {
    TaxTreatment.taxable => 'taxable',
    TaxTreatment.zeroRated => 'zero_rated',
    TaxTreatment.exempt => 'exempt',
    TaxTreatment.outOfScope => 'out_of_scope',
    TaxTreatment.reverseCharge => 'reverse_charge',
    TaxTreatment.import => 'import',
    TaxTreatment.manual => 'manual',
  };

  static TaxTreatment fromStorage(String? value) {
    for (final treatment in TaxTreatment.values) {
      if (treatment.storageValue == value) {
        return treatment;
      }
    }
    return TaxTreatment.taxable;
  }
}

class TaxCode extends Entity<TaxCode> {
  final int taxSchemeId;
  final String code;
  final String displayName;
  final int rateBasisPoints;
  final TaxTreatment taxTreatment;
  final String? jurisdictionName;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String? externalProvider;
  final String? externalTaxCode;
  final bool isDefaultSales;
  final bool isDefaultPurchase;

  TaxCode({
    required super.id,
    required this.taxSchemeId,
    required this.code,
    required this.displayName,
    required this.rateBasisPoints,
    required this.taxTreatment,
    required this.effectiveFrom,
    required this.isDefaultSales,
    required this.isDefaultPurchase,
    required super.createdDate,
    required super.modifiedDate,
    this.jurisdictionName,
    this.effectiveTo,
    this.externalProvider,
    this.externalTaxCode,
  }) : super();

  TaxCode.forInsert({
    required this.taxSchemeId,
    required this.code,
    required this.displayName,
    required this.rateBasisPoints,
    required this.taxTreatment,
    required this.effectiveFrom,
    required this.isDefaultSales,
    required this.isDefaultPurchase,
    this.jurisdictionName,
    this.effectiveTo,
    this.externalProvider,
    this.externalTaxCode,
  }) : super.forInsert();

  factory TaxCode.fromMap(Map<String, dynamic> map) => TaxCode(
    id: map['id'] as int,
    taxSchemeId: map['tax_scheme_id'] as int,
    code: map['code'] as String,
    displayName: map['display_name'] as String,
    rateBasisPoints: map['rate_basis_points'] as int? ?? 0,
    taxTreatment: TaxTreatment.fromStorage(map['tax_treatment'] as String?),
    jurisdictionName: map['jurisdiction_name'] as String?,
    effectiveFrom: DateTime.parse(map['effective_from'] as String),
    effectiveTo: map['effective_to'] == null
        ? null
        : DateTime.parse(map['effective_to'] as String),
    externalProvider: map['external_provider'] as String?,
    externalTaxCode: map['external_tax_code'] as String?,
    isDefaultSales: (map['is_default_sales'] as int? ?? 0) == 1,
    isDefaultPurchase: (map['is_default_purchase'] as int? ?? 0) == 1,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'tax_scheme_id': taxSchemeId,
    'code': code,
    'display_name': displayName,
    'rate_basis_points': rateBasisPoints,
    'tax_treatment': taxTreatment.storageValue,
    'jurisdiction_name': jurisdictionName,
    'effective_from': _dateOnly(effectiveFrom),
    'effective_to': effectiveTo == null ? null : _dateOnly(effectiveTo!),
    'external_provider': externalProvider,
    'external_tax_code': externalTaxCode,
    'is_default_sales': isDefaultSales ? 1 : 0,
    'is_default_purchase': isDefaultPurchase ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}

String _dateOnly(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
