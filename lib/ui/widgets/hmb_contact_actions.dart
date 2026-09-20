import 'package:material_ui/material_ui.dart';

import '../dialog/source_context.dart';
import 'text/hmb_email_text.dart';
import 'text/hmb_phone_text.dart';

/// Contact-specific communication controls, including clipboard actions.
/// Keep the supplied contact when resolving message-template placeholders.
class HMBContactActions extends StatelessWidget {
  final SourceContext sourceContext;

  const HMBContactActions({required this.sourceContext, super.key});

  @override
  Widget build(BuildContext context) {
    final contact = sourceContext.contact;
    final phone = contact?.bestPhone;
    final email = contact?.bestEmail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phone != null && phone.trim().isNotEmpty)
          HMBPhoneText(phoneNo: phone, sourceContext: sourceContext),
        if (email != null && email.trim().isNotEmpty)
          HMBEmailText(email: email),
      ],
    );
  }
}
