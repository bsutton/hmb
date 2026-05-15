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
  final VoidCallback? onSkip;
  final void Function(String)? onChanged;
  final VoidCallback? onExtractUnavailable;
  final String? initialMessage;
  final bool isExtracting;
  final bool extractAvailable;
  final String? helperText;
  final String extractLabel;

  const CustomerPastePanel({
    required this.onExtract,
    this.onSkip,
    this.onChanged,
    this.onExtractUnavailable,
    this.initialMessage,
    super.key,
    this.isExtracting = false,
    this.extractAvailable = true,
    this.helperText,
    this.extractLabel = 'Extract',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.helperText != null)
            Expanded(
              child: Text(
                widget.helperText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            const Spacer(),
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
            hint: 'Clear the pasted message',
            enabled: !widget.isExtracting,
          ),
        ],
      ),
      const SizedBox(height: 8),
      HMBTextArea(
        controller: controller,
        maxLines: 8,
        labelText: 'Paste Message (sms or email) here',
        leadingSpace: false,
        onChanged: (value) => widget.onChanged?.call(value ?? ''),
      ),
      const HMBSpacer(height: true),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (widget.onSkip != null)
            HMBButton(
              onPressed: widget.onSkip!,
              label: 'Skip extraction',
              hint: 'Continue without extracting details from a message',
              enabled: !widget.isExtracting,
            ),
          HMBButton(
            onPressed: () {
              if (widget.extractAvailable) {
                widget.onExtract(controller.text);
                return;
              }
              widget.onExtractUnavailable?.call();
            },
            label: widget.isExtracting ? 'Extracting...' : widget.extractLabel,
            hint: 'Extract customer details from the message',
            enabled: !widget.isExtracting,
          ),
        ],
      ),
    ],
  );
}
