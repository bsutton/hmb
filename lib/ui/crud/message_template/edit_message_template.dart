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

import 'package:flutter/material.dart';

import '../../../dao/dao_message_template.dart';
import '../../../entity/message_template.dart';
import '../../widgets/fields/hmb_text_area.dart';
import '../../widgets/layout/layout.g.dart' show HMBColumn;
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/edit_entity_screen.dart';

class MessageTemplateEditScreen extends StatefulWidget {
  final MessageTemplate? messageTemplate;

  const MessageTemplateEditScreen({super.key, this.messageTemplate});

  @override
  // ignore: library_private_types_in_public_api
  _MessageTemplateEditScreenState createState() =>
      _MessageTemplateEditScreenState();
}

class _MessageTemplateEditScreenState extends State<MessageTemplateEditScreen>
    implements EntityState<MessageTemplate> {
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late bool _enabled;

  @override
  MessageTemplate? currentEntity;

  @override
  void initState() {
    super.initState();
    currentEntity ??= widget.messageTemplate;
    _titleController = TextEditingController(
      text: widget.messageTemplate?.title,
    );
    _messageController = TextEditingController(
      text: widget.messageTemplate?.message,
    );
    _enabled = widget.messageTemplate?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<MessageTemplate>(
    entityName: 'Message Template',
    dao: DaoMessageTemplate(),
    entityState: this,
    editor: (messageTemplate, {required isNew}) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (messageTemplate == null ||
            messageTemplate.owner == MessageTemplateOwner.user) ...[
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
          ),
          HMBTextArea(
            controller: _messageController,
            labelText: 'Message',
            maxLines: 5,
          ),
        ] else ...[
          ListTile(
            title: Text(_titleController.text),
            subtitle: const HMBTextHeadline(
              'System templates cannot be edited!',
            ),
          ),
        ],
        SwitchListTile(
          title: Text(_enabled ? 'Enabled' : 'Disabled'),
          value: _enabled,
          onChanged: (value) {
            setState(() {
              _enabled = value;
            });
          },
        ),
      ],
    ),
  );

  @override
  Future<MessageTemplate> forUpdate(MessageTemplate messageTemplate) async =>
      messageTemplate.copyWith(
        title: _titleController.text,
        message: _messageController.text,
        owner: _coerceOwner(messageTemplate.owner, messageTemplate.title),
        messageType: messageTemplate.messageType,
        enabled: _enabled,
      );

  @override
  Future<MessageTemplate> forInsert() async => MessageTemplate.forInsert(
    title: _titleController.text,
    message: _messageController.text,
    ordinal: await _nextOrdinal(),
    enabled: _enabled,
    messageType: MessageType.sms,
  );

  @override
  Future<void> postSave(_) async {
    setState(() {});
  }

  Future<int> _nextOrdinal() async {
    final db = DaoMessageTemplate().withoutTransaction();
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(ordinal), 0) AS max_ordinal '
      'FROM message_template '
      'WHERE message_type = ?',
      [MessageType.sms.name],
    );
    final rawMax = rows.first['max_ordinal'];
    final maxOrdinal = rawMax is int
        ? rawMax
        : int.tryParse(rawMax.toString()) ?? 0;

    return maxOrdinal + 1;
  }

  MessageTemplateOwner _coerceOwner(MessageTemplateOwner owner, String title) {
    final trimmed = title.trim().toLowerCase();
    if (trimmed == 'thank you for choosing me' ||
        trimmed == 'thank you for choosing us') {
      return MessageTemplateOwner.system;
    }
    return owner;
  }
}
