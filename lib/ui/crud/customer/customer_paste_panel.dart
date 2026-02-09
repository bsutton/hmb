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
  final void Function(String)? onChanged;
  final String? initialMessage;
  final bool isExtracting;

  const CustomerPastePanel({
    required this.onExtract,
    this.onChanged,
    this.initialMessage,
    super.key,
    this.isExtracting = false,
  });

  @override
  State<CustomerPastePanel> createState() => _CustomerPastePanelState();
}

class _CustomerPastePanelState extends DeferredState<CustomerPastePanel> {
  final controller = TextEditingController();

  @override
  Future<void> asyncInitState() async {
    if (widget.initialMessage != null) {
      controller.text = widget.initialMessage!;
      return;
    }

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
              if (widget.isExtracting) {
                return;
              }
              controller.text = await clipboardGetText();
              widget.onChanged?.call(controller.text);
            },
            hint: 'Paste data from the clipboard',
            enabled: !widget.isExtracting,
          ),
          HMBClearIcon(
            onPressed: () async {
              if (widget.isExtracting) {
                return;
              }
              controller.text = '';
              widget.onChanged?.call(controller.text);
            },
            hint: 'Clear the message field',
            enabled: !widget.isExtracting,
          ),
        ],
      ),
      HMBTextArea(
        controller: controller,
        maxLines: 8,
        labelText: 'Paste Message (sms or email) here',
        onChanged: (value) => widget.onChanged?.call(value ?? ''),
      ),
      const HMBSpacer(height: true),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const HMBSpacer(width: true),
          HMBButton(
            onPressed: () => widget.onExtract(controller.text),
            label: widget.isExtracting ? 'Extracting...' : 'Extract',
            hint: 'Extract customer details from the message',
            enabled: !widget.isExtracting,
          ),
        ],
      ),
    ],
  );
}
