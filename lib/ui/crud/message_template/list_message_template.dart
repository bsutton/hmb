import 'package:flutter/material.dart';

import '../../../dao/dao_message_template.dart';
import '../../../entity/message_template.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_message_template.dart';

class MessageTemplateListScreen extends StatelessWidget {
  const MessageTemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<MessageTemplate>(
        pageTitle: 'SMS Templates',
        dao: DaoMessageTemplate(),
        title: (entity) => HMBTextHeadline2(entity.title),
        fetchList: (filter) async => DaoMessageTemplate().getByFilter(filter),
        onEdit: (smsTemplate) =>
            MessageTemplateEditScreen(messageTemplate: smsTemplate),

        // smsTemplate?.type == SmsTemplateType.user
        //     ? SmsTemplateEditScreen(smsTemplate: smsTemplate)
        //     : const Center(
        //         child:
        //           HMBTextHeadline('You may not edit a System SMS Template')),
        details: SmsTemplateDetails.new,
      );
}

class SmsTemplateDetails extends StatelessWidget {
  const SmsTemplateDetails(this.smsTemplate, {super.key});
  final MessageTemplate smsTemplate;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(smsTemplate.message),
          const Divider(height: 20, thickness: 1),
          Text(
            '''
Type: ${smsTemplate.owner == MessageTemplateOwner.system ? "System" : "User"}''',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}
