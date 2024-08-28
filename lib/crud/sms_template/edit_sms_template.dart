import 'package:flutter/material.dart';

import '../../dao/dao_sms_template.dart';
import '../../entity/sms_template.dart';
import '../../widgets/hmb_text_themes.dart';
import '../base_full_screen/edit_entity_screen.dart';

class SmsTemplateEditScreen extends StatefulWidget {
  const SmsTemplateEditScreen({super.key, this.smsTemplate});
  final SmsTemplate? smsTemplate;

  @override
  // ignore: library_private_types_in_public_api
  _SmsTemplateEditScreenState createState() => _SmsTemplateEditScreenState();
}

class _SmsTemplateEditScreenState extends State<SmsTemplateEditScreen>
    implements EntityState<SmsTemplate> {
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.smsTemplate?.title);
    _messageController =
        TextEditingController(text: widget.smsTemplate?.message);
    _enabled = widget.smsTemplate?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EntityEditScreen<SmsTemplate>(
        entity: widget.smsTemplate,
        entityName: 'SMS Template',
        dao: DaoSmsTemplate(),
        entityState: this,
        editor: (smsTemplate) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (smsTemplate?.type == SmsTemplateType.user) ...[
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
  Future<SmsTemplate> forUpdate(SmsTemplate smsTemplate) async =>
      SmsTemplate.forUpdate(
        entity: smsTemplate,
        title: _titleController.text,
        message: _messageController.text,
        type: smsTemplate.type,
        enabled: _enabled,
      );

  @override
  Future<SmsTemplate> forInsert() async => SmsTemplate.forInsert(
        title: _titleController.text,
        message: _messageController.text,
        enabled: _enabled,
      );

  @override
  void refresh() {
    setState(() {});
  }
}
