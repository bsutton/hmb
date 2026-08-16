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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../util/dart/app_settings.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';

class GoogleCalendarIntegrationScreen extends StatefulWidget {
  const GoogleCalendarIntegrationScreen({super.key});

  @override
  State<GoogleCalendarIntegrationScreen> createState() =>
      _GoogleCalendarIntegrationScreenState();
}

class _GoogleCalendarIntegrationScreenState
    extends DeferredState<GoogleCalendarIntegrationScreen> {
  bool _enabled = AppSettings.googleCalendarSyncEnabledDefault;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('Google Calendar Integration');
    _enabled = await AppSettings.getGoogleCalendarSyncEnabled();
  }

  Future<bool> _save({required bool close}) async {
    await AppSettings.setGoogleCalendarSyncEnabled(enabled: _enabled);
    if (mounted) {
      HMBToast.info('Google Calendar preference saved.');
      if (close) {
        context.go('/home/settings/integrations');
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DeferredBuilder(
      this,
      waitingBuilder: (context) => const SizedBox.shrink(),
      builder: (context) => HMBColumn(
        children: [
          SaveAndClose(
            onSave: _save,
            showSaveOnly: false,
            onCancel: () async => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'HMB can copy schedule events to your primary Google '
                  'Calendar. Schedule changes update the same calendar event '
                  'and deleting a schedule removes it.',
                ),
                const HMBSpacer(height: true),
                const Text(
                  'Safety and privacy: when you open directions for a job '
                  'that is not currently scheduled, HMB records that job '
                  'location in Google Calendar for one hour. Anyone who can '
                  'view that calendar may see where you travelled.',
                ),
                const HMBSpacer(height: true),
                SwitchListTile(
                  title: const Text('Google Calendar and safety sync'),
                  subtitle: const Text(
                    'Enabled by default. Turn this off to stop sending '
                    'schedule and navigation locations to Google Calendar.',
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const HMBSpacer(height: true),
                const Text(
                  'Google Calendar uses the Google account connected from '
                  'Backup. This is a one-way integration: changes made in '
                  'Google Calendar are not copied back into HMB.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
