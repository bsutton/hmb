/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

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

import '../../util/clip_board.dart';
import '../../util/platform_ex.dart';
import '../dialog/message_template_dialog.dart';
import '../dialog/source_context.dart';
import 'hmb_button.dart';
import 'hmb_toast.dart';

class HMBPhoneIcon extends StatelessWidget {
  const HMBPhoneIcon(this.phoneNo, {required this.sourceContext, super.key});
  final String phoneNo;

  final SourceContext sourceContext;

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
        onPressed: () async => Strings.isEmpty(phoneNo)
            ? null
            : await clipboardCopyTo(context, phoneNo),
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
              // await _showTextInputDialog(context, phoneNo);
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
    if (!Platform.isAndroid) {
      HMBToast.info('Dialing is only available on Android');
      return;
    }

    final status = await Permission.phone.status;
    if (status.isDenied) {
      final result = await Permission.phone.request();
      if (result.isDenied) {
        if (context.mounted) {
          HMBToast.info('Phone permission is required to make calls');
        }
        return;
      }
    }

    DirectCaller().makePhoneCall(phoneNo);
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

  // Future<void> _sendText2(
  //     BuildContext context, String phoneNo, String messageText) async {
  //   final status = await Permission.sms.status;
  //   if (status.isDenied) {
  //     final result = await Permission.sms.request();
  //     if (result.isDenied && context.mounted) {
  //       HMBToast.info('SMS permission is required to send texts');
  //       return;
  //     }
  //   }

  //   try {
  //     final sender = SmsSender();

  //     final message = SmsMessage(phoneNo, messageText);
  //     message.onStateChanged.listen((state) {
  //       if (state == SmsMessageState.Sent) {
  //         // TODO(bsutton): this won't show as the context is
  //         // gone by the time the notice arrives.
  //         // consider show a dialog that remains open util
  //         // the sms is sent.
  //         HMBToast.info('SMS sent successfully');
  //       } else if (state == SmsMessageState.Fail) {
  //         HMBToast.error('Failed to send SMS');
  //       }
  //     });
  //     await sender.sendSms(message);
  //     // ignore: avoid_catches_without_on_clauses
  //   } catch (e) {
  //     if (context.mounted) {
  //       HMBToast.error('Could not launch SMS application');
  //     }
  //   }
  // }

  Future<void> _showTextInputDialog(
    BuildContext context,
    String phoneNo,
  ) async {
    final messageText = await showDialog<String>(
      context: context,
      builder: (context) {
        var text = '';
        return AlertDialog(
          title: const Text('Send Text Message'),
          content: TextField(
            autofocus: isNotMobile,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (value) {
              text = value;
            },
            decoration: const InputDecoration(
              hintText: 'Enter your message here',
            ),
          ),
          actions: <Widget>[
            HMBButton(
              label: 'Cancel',
              hint: "Don't send the message",
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            HMBButton(
              label: 'Send...',
              hint: 'Send the message using your devices Text/SMS app',
              onPressed: () {
                Navigator.of(context).pop(text);
              },
            ),
          ],
        );
      },
    );

    if (messageText != null && messageText.isNotEmpty) {
      if (context.mounted) {
        await _sendText(context, phoneNo, messageText);
      }
    }
  }
}
