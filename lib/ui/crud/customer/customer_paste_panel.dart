import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../util/flutter/flutter_util.g.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/icons/hmb_clear_icon.dart';
import '../../widgets/icons/hmb_paste_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class CustomerPastePanel extends StatefulWidget {
  final void Function(String) onExtract;

  const CustomerPastePanel({required this.onExtract, super.key});

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
  Widget build(BuildContext context) => HMBColumn(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          HMBPasteIcon(
            onPressed: () async {
              controller.text = await clipboardGetText();
            },
            hint: 'Paste data from the clipboard',
          ),
          HMBClearIcon(
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
            onPressed: () => widget.onExtract(controller.text),
            label: 'Extract',
            hint: 'Extract customer details from the message',
          ),
        ],
      ),
    ],
  );
}
