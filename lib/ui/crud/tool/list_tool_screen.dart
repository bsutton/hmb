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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao_category.dart';
import '../../../dao/dao_tool.dart';
import '../../../entity/tool.dart';
import '../../../util/dart/format.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_tool_screen.dart';
import 'stock_take_wizard.dart';

class ToolListScreen extends StatefulWidget {
  const ToolListScreen({super.key});

  @override
  State<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends State<ToolListScreen> {
  var _refreshCounter = 0;

  Future<void> _startStockTake(BuildContext context) async {
    await ToolStockTakeWizard.start(
      context: context,
      offerAnother: true,
      onFinish: (reason) async {
        Navigator.of(context).pop();
        setState(() {
          _refreshCounter++;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: HMBButton.withIcon(
            onPressed: () => unawaited(_startStockTake(context)),
            label: 'Start Stock Take',
            hint:
                '''Undertake a stock take of your tools adding new tools to your Tool inventory''',
            icon: const Icon(Icons.inventory),
          ),
        ),
      ],
    ),
    body: EntityListScreen<Tool>(
      key: ValueKey(_refreshCounter),
      pageTitle: 'Tools',
      dao: DaoTool(),
      title: (entity) => HMBTextHeadline2(entity.name),
      // ignore: discarded_futures
      fetchList: (filter) => DaoTool().getByFilter(filter),
      onEdit: (tool) => ToolEditScreen(tool: tool),
      cardHeight: 470,
      details: (entity) {
        final tool = entity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoCategory().getById(tool.categoryId),
              builder: (context, category) =>
                  HMBTextBody('Category: ${category?.name ?? 'Not Set'}'),
            ),
            if (tool.datePurchased != null)
              HMBTextBody('Purchased: ${formatDate(tool.datePurchased!)}'),
            if (tool.description != null)
              HMBTextBody('Description: ${tool.description}'),
            if (tool.serialNumber != null)
              HMBTextBody('Serial No.: ${tool.serialNumber}'),
            if (tool.warrantyPeriod != null)
              HMBTextBody('Warranty: ${tool.warrantyPeriod} months'),
            if (tool.cost != null) HMBTextBody('Cost: ${tool.cost}'),
            PhotoGallery.forTool(
              tool: tool,
              filter: (photo) =>
                  !(photo.id == tool.serialNumberPhotoId ||
                      photo.id == tool.receiptPhotoId),
            ),
          ],
        );
      },
    ),
  );
}
