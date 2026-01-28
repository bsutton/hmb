/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:io';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dao/dao.g.dart';
import '../../entity/entity.g.dart';
import '../widgets/hmb_button.dart';
import '../widgets/hmb_toast.dart';
import '../widgets/icons/help_button.dart';
import '../widgets/select/hmb_select_email_multi.dart';
import '../widgets/select/hmb_select_mobile_multi.dart';

enum _Channel { email, sms }

class SendNoticeForJobDialog extends StatefulWidget {
  final Job job;

  /// Optional activity; if present, we stamp noticeSentDate on success.
  final JobActivity jobActivity;

  /// Optional initial subject/body (we’ll fill with schedule text if blank).
  final String? initialSubject;
  final String? initialBody;

  /// If provided, we’ll try to preselect these (email or mobile based on tab).
  final String? preferredEmailRecipient;
  final String? preferredMobileRecipient;

  const SendNoticeForJobDialog({
    required this.job,
    required this.jobActivity,
    this.initialSubject,
    this.initialBody,
    this.preferredEmailRecipient,
    this.preferredMobileRecipient,
    super.key,
  });

  @override
  State<SendNoticeForJobDialog> createState() => _SendNoticeForJobDialogState();

  static Future<void> show(
    BuildContext context,
    Job job,
    JobActivity jobActivity,
  ) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => SendNoticeForJobDialog(
        job: job,
        jobActivity: jobActivity, // optional
      ),
    );
    if (sent ?? false) {
      // refresh UI if needed
    }
  }
}

class _SendNoticeForJobDialogState
    extends DeferredState<SendNoticeForJobDialog> {
  late final System _system;
  late TextEditingController _subjectCtl;
  late TextEditingController _bodyCtl;
  late TextEditingController _smsBodyCtl;

  _Channel _channel = _Channel.sms;

  List<String> _toEmails = [];
  List<String> _ccEmails = [];
  List<String> _toMobiles = [];

  @override
  Future<void> asyncInitState() async {
    _system = await DaoSystem().get();

    // Prefill subject/body from schedule if available.
    final scheduleText = await _buildScheduleLine(widget.job);
    final defaultSubject = widget.initialSubject ?? 'Scheduled Job Notice';
    final defaultBody =
        widget.initialBody ??
        '''
Hello,

This is a notice for your scheduled job.

$scheduleText

Regards,
${_system.businessName}
${_system.address}
Email: ${_system.emailAddress}
Phone: ${_system.bestPhone}
${Strings.isNotBlank(_system.webUrl) ? 'Web: ${_system.webUrl}' : ''}
${Strings.isNotBlank(_system.businessNumber) ? '${Strings.orElseOnBlank(_system.businessNumberLabel, 'Business No.')}${_system.businessNumber}' : ''}
''';

    _subjectCtl = TextEditingController(text: defaultSubject);
    _bodyCtl = TextEditingController(text: defaultBody);

    // SMS body is shorter; keep it simple and template-friendly.
    _smsBodyCtl = TextEditingController(
      text: 'Hi, your job is scheduled. $scheduleText\n${_system.businessName}',
    );

    // Smart default: prefer SMS tab and preselect primary contact mobile.
    _channel = _Channel.sms;
    final primary = await _primaryContactForJob(widget.job);
    if (primary != null && Strings.isNotBlank(primary.mobileNumber)) {
      _toMobiles = [primary.mobileNumber];
    }

    // If caller supplied a preferred recipient, respect it.
    if (Strings.isNotBlank(widget.preferredMobileRecipient)) {
      _toMobiles = [widget.preferredMobileRecipient!];
    }
    if (Strings.isNotBlank(widget.preferredEmailRecipient)) {
      _toEmails = [widget.preferredEmailRecipient!];
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (_) => AlertDialog(
      title: const Text('Send Scheduled Job Notice'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Channel toggle
            SegmentedButton<_Channel>(
              segments: const [
                ButtonSegment(
                  value: _Channel.sms,
                  label: Text('SMS'),
                  icon: Icon(Icons.sms),
                ),
                ButtonSegment(
                  value: _Channel.email,
                  label: Text('Email'),
                  icon: Icon(Icons.email),
                ),
              ],
              selected: {_channel},
              onSelectionChanged: (v) {
                setState(() {
                  _channel = v.first;
                });
              },
            ),
            const SizedBox(height: 12),

            if (_channel == _Channel.sms) ...[
              HMBSelectMobileMulti(
                job: widget.job,
                initialMobiles: _toMobiles,
                onChanged: (mobiles) {
                  setState(() {
                    _toMobiles = mobiles;
                  });
                },
              ),
              TextField(
                controller: _smsBodyCtl,
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 4,
              ),
            ] else ...[
              HMBSelectEmailMulti(
                job: widget.job,
                initialEmails: _toEmails,
                onChanged: (emails) {
                  setState(() {
                    _toEmails = emails;
                  });
                },
              ),
              const SizedBox(height: 8),
              // Optional CC
              HMBSelectEmailMulti(
                job: widget.job,
                initialEmails: _ccEmails,
                onChanged: (emails) {
                  setState(() {
                    _ccEmails = emails;
                  });
                },
              ).help('CC (optional)', '''
Add additional recipients who should receive a copy of the email.'''),
              TextField(
                controller: _subjectCtl,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              TextField(
                controller: _bodyCtl,
                decoration: const InputDecoration(labelText: 'Body'),
                maxLines: 6,
              ),
            ],
          ],
        ),
      ),
      actions: [
        HMBButton(
          label: 'Cancel',
          hint: 'Close without sending',
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        HMBButton(
          label: 'Send...',
          hint: 'Launch your device app to review and send the message.',
          onPressed: () async {
            if (_channel == _Channel.sms) {
              await _sendSms(context);
            } else {
              await _sendEmail(context);
            }
          },
        ),
      ],
    ),
  );

  Future<void> _sendSms(BuildContext context) async {
    if (_toMobiles.isEmpty) {
      HMBToast.info('Please select at least one mobile number');
      return;
    }

    // iOS accepts comma-separated recipients, Android historically uses
    // semicolons in some handlers. Modern apps usually accept commas; we
    // fall back to semicolons on Android to be safe.
    final sep = Platform.isAndroid ? ';' : ',';
    final path = _toMobiles.join(sep);

    final uri = Uri(
      scheme: 'sms',
      path: path,
      queryParameters: <String, String>{'body': _smsBodyCtl.text},
    );

    final ok = await launchUrl(uri);
    if (!ok) {
      if (context.mounted) {
        HMBToast.error('Could not launch SMS application');
      }
      return;
    }

    await _stampNoticeSent();
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      HMBToast.error('Email sending is only supported on mobile');
      return;
    }
    if (_toEmails.isEmpty) {
      HMBToast.info('Please select at least one email address');
      return;
    }

    final email = Email(
      body: _bodyCtl.text,
      subject: _subjectCtl.text,
      recipients: _toEmails,
      cc: _ccEmails,
      // Attachments can be added by the caller in a future enhancement.
    );

    await FlutterEmailSender.send(email);

    HMBToast.info('Email send initiated');
    await _stampNoticeSent();
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _stampNoticeSent() async {
    final updated = widget.jobActivity.copyWith(noticeSentDate: DateTime.now());
    await DaoJobActivity().update(updated);
  }

  // Formats a single-line schedule summary for message bodies.
  Future<String> _buildScheduleLine(Job job) async {
    // Use your existing date/time formatting helpers if available.
    final start = widget.jobActivity.start; // Localtime assumed
    final end = widget.jobActivity.end;
    final dateStr = '''
${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}''';
    final startStr =
        '''${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}''';
    final endStr =
        '''${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}''';

    return 'Date: $dateStr, Time: $startStr – $endStr';
  }

  /// Tries (in order) to find the primary contact for the job.
  Future<Contact?> _primaryContactForJob(Job job) async {
    // 1) If your Job has a contactId, prefer that.
    if (job.contactId != null) {
      final c = await DaoContact().getById(job.contactId);
      if (c != null) {
        return c;
      }
    }

    // 2) Otherwise ask DAO for a designated primary contact if supported.
    try {
      final c = await DaoContact().getPrimaryForJob(job.id);
      if (c != null) {
        return c;
      }
    } catch (_) {}

    // 3) Otherwise first contact with a mobile.
    final contacts = await DaoContact().getByJob(job.id);
    for (final c in contacts) {
      if (Strings.isNotBlank(c.mobileNumber)) {
        return c;
      }
    }

    return contacts.isNotEmpty ? contacts.first : null;
  }
}
