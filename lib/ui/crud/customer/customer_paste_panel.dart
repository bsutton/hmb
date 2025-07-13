import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../../util/parse.dart';
import '../../../util/util.g.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import 'parse_address.dart';

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
            onPressed: () =>
                widget.onExtract(ParsedCustomer.parse(controller.text)),
            label: 'Extract',
            hint: 'Extract customer details from the message',
          ),
        ],
      ),
    ],
  );
}

// {
// HMBToast.info(
//   'Unable to extract any customer details from the message. You can copy and paste the details manually.',
// );

class ParsedCustomer {
  ParsedCustomer({
    required this.customerName,
    required this.email,
    required this.firstname,
    required this.surname,
    required this.mobile,
    required this.address,
  });

  factory ParsedCustomer.parse(String text) {
    final email = parseEmail(text);
    final mobile = parsePhone(text);

    final nameMatch = RegExp(
      r'\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b',
    ).firstMatch(text);
    final matchCount = nameMatch?.groupCount ?? 0;
    var firstName = '';
    if (matchCount > 0) {
      firstName = nameMatch!.group(1) ?? '';
    }

    var surname = '';
    if (matchCount > 1) {
      surname = nameMatch!.group(2) ?? '';
    }

    final address = ParsedAddress.parse(text);

    final customerName = '$firstName $surname';

    return ParsedCustomer(
      customerName: customerName,
      email: email,
      mobile: mobile,
      firstname: firstName,
      surname: surname,
      address: address,
    );
  }

  String customerName;
  String email;
  String mobile;
  String firstname;
  String surname;
  ParsedAddress address;

  bool isEmpty() =>
      Strings.isBlank(firstname) &&
      Strings.isBlank(surname) &&
      Strings.isBlank(email) &&
      Strings.isBlank(mobile) &&
      Strings.isBlank(customerName) &&
      address.isEmpty();
}
