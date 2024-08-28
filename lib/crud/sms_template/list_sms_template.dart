import 'package:flutter/material.dart';

import '../../dao/dao_sms_template.dart';
import '../../entity/sms_template.dart';
import '../../widgets/hmb_text_themes.dart';
import '../base_full_screen/list_entity_screen.dart';
import 'edit_sms_template.dart';

class SmsTemplateListScreen extends StatelessWidget {
  const SmsTemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) => EntityListScreen<SmsTemplate>(
        pageTitle: 'SMS Templates',
        dao: DaoSmsTemplate(),
        title: (entity) => HMBTextHeadline2(entity.title),
        fetchList: (filter) async => DaoSmsTemplate().getByFilter(filter),
        onEdit: (smsTemplate) =>
            SmsTemplateEditScreen(smsTemplate: smsTemplate),

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
  final SmsTemplate smsTemplate;

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
Type: ${smsTemplate.type == SmsTemplateType.system ? "System" : "User"}''',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}
