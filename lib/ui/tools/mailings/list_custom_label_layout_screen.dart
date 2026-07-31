/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../dao/dao_custom_label_layout.dart';
import '../../../entity/custom_label_layout.dart';
import '../../../util/dart/measurement_type.dart';
import '../../crud/base_full_screen/list_entity_screen.dart';
import '../../widgets/icons/hmb_copy_icon.dart';
import '../../widgets/text/hmb_text_themes.dart';
import 'edit_custom_label_layout_screen.dart';

class CustomLabelLayoutListScreen extends StatelessWidget {
  final PreferredUnitSystem unitSystem;

  const CustomLabelLayoutListScreen({required this.unitSystem, super.key});

  @override
  Widget build(BuildContext context) {
    final dao = DaoCustomLabelLayout();
    return EntityListScreen<CustomLabelLayout>(
      entityNameSingular: 'Custom Label',
      entityNamePlural: 'Custom Labels',
      dao: dao,
      showBackButton: true,
      cardHeight: 170,
      fetchList: (filter) => dao.getByFilterForUnitSystem(filter, unitSystem),
      onEdit: (layout) =>
          CustomLabelLayoutEditScreen(layout: layout, unitSystem: unitSystem),
      listCardTitle: (layout) => HMBTextHeadline2(layout.name),
      listCard: (layout) => HMBTextBody(_summary(layout)),
      buildActionItems: (layout) => [
        HMBCopyIcon(
          hint: 'Duplicate this custom label',
          onPressed: () => _duplicate(context, layout),
        ),
      ],
    );
  }

  Future<void> _duplicate(
    BuildContext context,
    CustomLabelLayout layout,
  ) async {
    await Navigator.push<CustomLabelLayout?>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomLabelLayoutEditScreen(
          layout: layout,
          unitSystem: unitSystem,
          duplicate: true,
        ),
      ),
    );
  }

  String _summary(CustomLabelLayout layout) {
    final unit = layout.unitSystem == PreferredUnitSystem.metric ? 'mm' : 'in';
    final factor = layout.unitSystem == PreferredUnitSystem.metric
        ? PdfPageFormat.mm
        : PdfPageFormat.inch;
    String display(double points) {
      final value = points / factor;
      return value.toStringAsFixed(value >= 10 ? 1 : 2);
    }

    return '${layout.columns} across x ${layout.rows} down, '
        '${display(layout.labelWidth)} x ${display(layout.labelHeight)} $unit, '
        '${display(layout.pageWidth)} x ${display(layout.pageHeight)} '
        '$unit page';
  }
}
