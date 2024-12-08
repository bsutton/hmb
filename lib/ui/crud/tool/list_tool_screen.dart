import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao_category.dart';
import '../../../dao/dao_tool.dart';
import '../../../entity/tool.dart';
import '../../../util/format.dart';
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
  int _refreshCounter = 0;

  Future<void> _startStockTake(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ToolStockTakeWizard(onFinish: (reason) async {
        // Pop the wizard
        Navigator.of(context).pop();
        // Refresh the list
        setState(() {
          _refreshCounter++;
        });

        // Show a dialog asking if the user wants to add another
        final addAnother = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add Another?'),
            content: const Text(
                'Would you like to run the stock take wizard again?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );

        // If the user chooses to add another, re-launch the wizard
        if ((addAnother ?? false) && context.mounted) {
          await _startStockTake(context);
        }
      }),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Tools'),
          actions: [
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: () async => _startStockTake(context),
              tooltip: 'Start Tool Stock Take',
            ),
          ],
        ),
        body: EntityListScreen<Tool>(
          key: ValueKey(_refreshCounter),
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
                    builder: (context, category) => HMBTextBody(
                        'Category: ${category?.name ?? 'Not Set'}')),
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
                    filter: (photo) => !(photo.id == tool.serialNumberPhotoId ||
                        photo.id == tool.receiptPhotoId))
              ],
            );
          },
        ),
      );
}
