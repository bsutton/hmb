import 'package:flutter/material.dart';

import '../../../dao/dao_message_template.dart';
import '../../../entity/message_template.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/edit_entity_screen.dart';

class MessageTemplateEditScreen extends StatefulWidget {
  const MessageTemplateEditScreen({super.key, this.messageTemplate});
  final MessageTemplate? messageTemplate;

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
    _titleController =
        TextEditingController(text: widget.messageTemplate?.title);
    _messageController =
        TextEditingController(text: widget.messageTemplate?.message);
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
        editor: (messageTemplate, {required isNew}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (messageTemplate?.owner == MessageTemplateOwner.user) ...[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
              ),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: 'Message'),
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                textInputAction: TextInputAction.done,
              ),
            ] else ...[
              ListTile(
                title: Text(_titleController.text),
                subtitle:
                    const HMBTextHeadline('System templates cannot be edited!'),
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
      MessageTemplate.forUpdate(
        entity: messageTemplate,
        ordinal: messageTemplate.ordinal,
        title: _titleController.text,
        message: _messageController.text,
        owner: MessageTemplateOwner.user,
        messageType: messageTemplate.messageType,
        enabled: _enabled,
      );

  @override
  Future<MessageTemplate> forInsert() async => MessageTemplate.forInsert(
      title: _titleController.text,
      message: _messageController.text,
      enabled: _enabled,
      messageType: MessageType.sms);

  @override
  void refresh() {
    setState(() {});
  }
}
