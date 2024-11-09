import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_category.dart';
import '../../dao/dao_tool.dart';
import '../../entity/tool.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_tool_screen.dart';

class ToolListScreen extends StatelessWidget {
  const ToolListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<Tool>(
      pageTitle: 'Tools',
      dao: DaoTool(),
      title: (entity) => HMBTextHeadline2(entity.name),
      fetchList: (filter) async => DaoTool().getByFilter(filter),
      onEdit: (tool) => ToolEditScreen(tool: tool),
      details: (entity) {
        final tool = entity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilderEx(
                // ignore: discarded_futures
                future: DaoCategory().getById(tool.categoryId),
                builder: (context, category) =>
                    HMBTextBody('Category: ${category?.name ?? 'Not Set'}')),
            if (tool.description != null)
              HMBTextBody('Description: ${tool.description}'),
            if (tool.serialNumber != null)
              HMBTextBody('Serial No.: ${tool.serialNumber}'),
            if (tool.warrantyPeriod != null)
              HMBTextBody('Warranty: ${tool.warrantyPeriod} months'),
            if (tool.cost != null) HMBTextBody('Cost: \$${tool.cost}'),
            if (tool.receiptPhotoPath != null)
              HMBTextBody('Receipt Photo: ${tool.receiptPhotoPath}'),
            if (tool.serialNumberPhotoPath != null)
              HMBTextBody('Serial No. Photo: ${tool.serialNumberPhotoPath}'),
          ],
        );
      });
}
