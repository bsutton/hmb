/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';
import 'dart:io';

import 'package:direct_caller_sim_choice/direct_caller_sim_choice.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:sms_advanced/sms_advanced.dart';
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../dao/dao_system.dart';
import '../../../util/flutter/clip_board.dart';
import '../../dialog/message_template_dialog.dart';
import '../../dialog/source_context.dart';
import '../hmb_button.dart';
import '../hmb_toast.dart';

class HMBPhoneIcon extends StatelessWidget {
  final String phoneNo;
  final SourceContext sourceContext;

  const HMBPhoneIcon(this.phoneNo, {required this.sourceContext, super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, // added line
    mainAxisSize: MainAxisSize.min, // added line
    children: [
      IconButton(
        iconSize: 22,
        icon: const Icon(Icons.phone),
        onPressed: () async => Strings.isEmpty(phoneNo)
            ? null
            : await _showOptions(context, phoneNo),
        color: Strings.isEmpty(phoneNo) ? Colors.grey : Colors.blue,
        tooltip: 'Call or Text',
      ),
      IconButton(
        iconSize: 22,
        icon: const Icon(Icons.copy),
        onPressed: () async =>
            Strings.isEmpty(phoneNo) ? null : await clipboardCopyTo(phoneNo),
        color: Strings.isEmpty(phoneNo) ? Colors.grey : Colors.blue,
        tooltip: 'Copy Phone No. to the Clipboard',
      ),
    ],
  );

  Future<void> _showOptions(BuildContext context, String phoneNo) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Options'),
        content: const Text(
          'Would you like to make a call or send a text message?',
        ),
        actions: <Widget>[
          HMBButton(
            label: 'Call',
            hint: 'Open your phone dialer app to call this number',
            onPressed: () {
              Navigator.of(context).pop();
              unawaited(_call(context, phoneNo));
            },
          ),
          HMBButton(
            label: 'Text',
            hint: 'Send a Text/SMS message',
            onPressed: () async {
              // await _promptTextThenSend(context, phoneNo);
              final template = await showMessageTemplateDialog(
                context,
                sourceContext: sourceContext,
              );
              if (context.mounted) {
                if (template != null) {
                  if (context.mounted) {
                    await _sendText(
                      context,
                      phoneNo,
                      template.getFormattedMessage(),
                    );
                  }
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          HMBButton(
            label: 'Cancel',
            hint: 'Take no action',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String phoneNo) async {
    if (Platform.isAndroid && await _directCall(phoneNo)) {
      return;
    }

    final launched = await launchUrl(Uri(scheme: 'tel', path: phoneNo));
    if (!launched && context.mounted) {
      HMBToast.error('Unable to open the phone dialer.');
    }
  }

  Future<bool> _directCall(String phoneNo) async {
    final status = await Permission.phone.status;
    if (status.isDenied) {
      final result = await Permission.phone.request();
      if (result.isDenied) {
        return false;
      }
    }

    try {
      final simSlot = _validSimSlot((await DaoSystem().get()).simCardNo);
      final caller = DirectCaller();
      if (simSlot == null) {
        return caller.makePhoneCall(phoneNo);
      }
      return caller.makePhoneCall(phoneNo, simSlot: simSlot);
      // The caller plugin can throw for unsupported SIM slot values or
      // platform-specific intent failures. Fall back to the dialer.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return false;
    }
  }

  Future<void> _sendText(
    BuildContext context,
    String phoneNo,
    String messageText,
  ) async {
    final smsLaunchUri = Uri(
      scheme: 'sms',
      path: phoneNo,
      queryParameters: <String, String>{'body': messageText},
    );

    await launchUrl(smsLaunchUri);
  }

  int? _validSimSlot(int? value) => switch (value) {
    1 || 2 => value,
    _ => null,
  };
}
