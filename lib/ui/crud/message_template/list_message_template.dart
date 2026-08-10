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

import '../../../dao/dao_message_template.dart';
import '../../../entity/message_template.dart';
import '../../../util/flutter/app_title.dart';
import '../../dialog/hmb_comfirm_delete_dialog.dart';
import '../../widgets/icons/hmb_delete_icon.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../../widgets/widgets.g.dart';
import 'edit_message_template.dart';

class MessageTemplateListScreen extends StatefulWidget {
  const MessageTemplateListScreen({super.key});

  @override
  State<MessageTemplateListScreen> createState() =>
      _MessageTemplateListScreenState();
}

class _MessageTemplateListScreenState extends State<MessageTemplateListScreen> {
  final dao = DaoMessageTemplate();

  List<MessageTemplate> templates = [];
  String? filter;

  @override
  void initState() {
    super.initState();
    setAppTitle('SMS Templates');
    unawaited(_refresh());
  }

  Future<void> _refresh([String? query]) async {
    final loaded = await dao.getByFilter(query);
    if (!mounted) {
      return;
    }
    setState(() {
      filter = query;
      templates = loaded;
    });
  }

  @override
  Widget build(BuildContext context) => Surface(
    elevation: SurfaceElevation.e0,
    padding: EdgeInsets.zero,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: SurfaceElevation.e0.color,
        toolbarHeight: 80,
        titleSpacing: 0,
        title: HMBSearchWithAdd(
          onSearch: (newValue) async {
            await _refresh(newValue);
          },
          onAdd: () async {
            final newTemplate = await Navigator.push<MessageTemplate?>(
              context,
              MaterialPageRoute(
                builder: (context) => const MessageTemplateEditScreen(),
              ),
            );
            if (newTemplate != null && mounted) {
              unawaited(_refresh(filter));
            }
          },
        ),
      ),
      body: _buildListBody(),
    ),
  );

  Widget _buildListBody() {
    if (templates.isEmpty) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Click'),
            HMBButtonAdd(
              small: true,
              enabled: false,
              hint: 'Not this one',
              onAdd: () async {},
            ),
            const Text('to add SMS Templates.'),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: templates.length,
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      itemBuilder: (context, index) =>
          _buildTemplateCard(context, templates[index], index),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final movedTemplate = templates[oldIndex];
    if (!mounted) {
      return;
    }

    final reordered = [...templates]..removeAt(oldIndex);
    final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    reordered.insert(targetIndex, movedTemplate);

    setState(() {
      templates = reordered;
    });

    try {
      await _persistOrdinals();
    } catch (error) {
      HMBToast.error(error.toString());
      await _refresh(filter);
    }
  }

  Future<void> _persistOrdinals() async {
    final updatedTemplates = <MessageTemplate>[];
    for (var index = 0; index < templates.length; index++) {
      final template = templates[index];
      if (template.ordinal == index) {
        continue;
      }

      final updated = template.copyWith(ordinal: index);
      templates[index] = updated;
      updatedTemplates.add(updated);
    }

    if (updatedTemplates.isEmpty) {
      return;
    }

    await dao.withTransaction((txn) async {
      for (final template in updatedTemplates) {
        await dao.update(template, txn);
      }
    });
  }

  Widget _buildTemplateCard(
    BuildContext context,
    MessageTemplate template,
    int index,
  ) => Surface(
    key: ValueKey(template.id),
    elevation: SurfaceElevation.e6,
    margin: const EdgeInsets.only(bottom: 8),
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: HMBTextHeadline2(template.title)),
            HMBRow(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
                HMBEditIcon(
                  hint: 'Edit this SMS Template',
                  onPressed: () => _edit(template),
                ),
                HMBDeleteIcon(
                  hint: 'Delete this SMS Template',
                  onPressed: () => _delete(template),
                ),
              ],
            ),
          ],
        ),
        SmsTemplateDetails(template),
      ],
    ),
  );

  Future<void> _edit(MessageTemplate template) async {
    final latestTemplate = await dao.getById(template.id);
    if (!mounted) {
      return;
    }

    final updatedTemplate = await Navigator.push<MessageTemplate?>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MessageTemplateEditScreen(messageTemplate: latestTemplate),
      ),
    );
    if (updatedTemplate != null && mounted) {
      unawaited(_refresh(filter));
    }
  }

  Future<void> _delete(MessageTemplate template) async {
    await showConfirmDeleteDialog(
      context: context,
      question: 'Are you sure you want to delete this SMS Template?',
      nameSingular: 'SMS Template',
      onConfirmed: () async {
        try {
          await dao.delete(template.id);
          if (mounted) {
            setState(() {
              templates.removeWhere((item) => item.id == template.id);
            });
          }
        } // ignore: avoid_catches_without_on_clauses
        catch (error) {
          HMBToast.error(error.toString());
        }
      },
    );
  }
}

class SmsTemplateDetails extends StatelessWidget {
  final MessageTemplate smsTemplate;

  const SmsTemplateDetails(this.smsTemplate, {super.key});

  @override
  Widget build(BuildContext context) => HMBColumn(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Message:',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      Text(smsTemplate.message),
      const Divider(height: 20, thickness: 1),
      Text(
        '''Type: ${smsTemplate.owner == MessageTemplateOwner.system ? "System" : "User"}''',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
