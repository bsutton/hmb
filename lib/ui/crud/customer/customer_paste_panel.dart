import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../util/parse/parse_customer.dart';
import '../../../util/util.g.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class CustomerPastePanel extends StatefulWidget {
  const CustomerPastePanel({required this.onExtract, super.key});

  final void Function(ParsedCustomer) onExtract;

  @override
  State<CustomerPastePanel> createState() => _CustomerPastePanelState();
}

class _CustomerPastePanelState extends DeferredState<CustomerPastePanel> {
  final controller = TextEditingController();

  @override
  Future<void> asyncInitState() async {
    final String clipboardText;
    if (await clipboardHasText()) {
      clipboardText = await clipboardGetText();
    } else {
      clipboardText = '';
    }

    controller.text = clipboardText;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          HMBIconButton(
            icon: const Icon(Icons.paste),
            size: HMBIconButtonSize.small,
            onPressed: () async {
              controller.text = await clipboardGetText();
            },
            hint: 'Paste data from the clipboard',
          ),
          HMBIconButton(
            size: HMBIconButtonSize.small,
            icon: const Icon(Icons.clear),
            onPressed: () async => controller.text = '',
            hint: 'Clear the message field',
          ),
        ],
      ),
      HMBTextArea(
        controller: controller,
        maxLines: 4,
        labelText: 'Paste Message (sms or email) here',
      ),
      const HMBSpacer(height: true),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const HMBSpacer(width: true),
          HMBButton(
            onPressed: () async =>
                widget.onExtract(await ParsedCustomer.parse(controller.text)),
            label: 'Extract',
            hint: 'Extract customer details from the message',
          ),
        ],
      ),
    ],
  );
}
