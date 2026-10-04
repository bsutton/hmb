import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/accounting/quickbooks_auth.dart';
import '../../../dao/dao_quickbooks.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/quickbooks_settings.dart';
import '../../../entity/system_credentials.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/hmb_form_section.dart';
import '../../widgets/widgets.g.dart';

class QuickBooksIntegrationScreen extends StatefulWidget {
  const QuickBooksIntegrationScreen({super.key});
  @override
  State<QuickBooksIntegrationScreen> createState() => _QuickBooksState();
}

class _QuickBooksState extends DeferredState<QuickBooksIntegrationScreen> {
  final _client = TextEditingController();
  final _secret = TextEditingController();
  final _redirect = TextEditingController();
  final _item = TextEditingController();
  final _taxable = TextEditingController();
  final _exempt = TextEditingController();
  final _transactionTax = TextEditingController();
  final _callback = TextEditingController();
  final _auth = QuickBooksAuth();
  var _sandbox = true;
  var _us = true;
  var _connecting = false;
  var _connected = false;

  @override
  Future<void> asyncInitState() async {
    setAppTitle('QuickBooks Online');
    final settings = await DaoQuickBooks().settings();
    _client.text = settings.clientId;
    _redirect.text = settings.redirectUri;
    _item.text = settings.itemId;
    _taxable.text = settings.taxableCode;
    _exempt.text = settings.exemptCode;
    _transactionTax.text = settings.transactionTaxCode;
    _sandbox = settings.sandbox;
    _us = settings.usTaxModel;
    _connected =
        (await DaoSystem().getQuickBooksCredentials()).tokenJson != null;
  }

  @override
  void dispose() {
    for (final controller in [
      _client,
      _secret,
      _redirect,
      _item,
      _taxable,
      _exempt,
      _transactionTax,
      _callback,
    ]) {
      controller.dispose();
    }
    _auth.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    await BlockingUI().runAndWait(() async {
      try {
        await action();
      } on FormatException catch (error) {
        HMBToast.error(error.message);
      } catch (_) {
        HMBToast.error('QuickBooks action failed. Check setup and connection.');
      }
    });
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    final old = await DaoQuickBooks().settings();
    final next = QuickBooksSettings(
      clientId: _client.text.trim(),
      redirectUri: _redirect.text.trim(),
      sandbox: _sandbox,
      itemId: _item.text.trim(),
      taxableCode: _taxable.text.trim(),
      exemptCode: _exempt.text.trim(),
      usTaxModel: _us,
      transactionTaxCode: _transactionTax.text.trim(),
    )..validateAuth();
    final secrets = await DaoSystem().getQuickBooksCredentials();
    final changed =
        old.clientId != next.clientId ||
        old.redirectUri != next.redirectUri ||
        old.sandbox != next.sandbox ||
        _secret.text.isNotEmpty;
    // Invalidate old authorization before persisting a new app/environment.
    if (changed) {
      _auth.cancel();
      _connecting = false;
      await DaoSystem().updateQuickBooksCredentials(
        QuickBooksCredentials(
          clientSecret: _secret.text.isEmpty
              ? secrets.clientSecret
              : _secret.text,
        ),
      );
      _connected = false;
    }
    await DaoQuickBooks().saveSettings(next);
    _secret.clear();
  }

  Future<void> _connect() async {
    await _save();
    final url = await _auth.begin();
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _auth.cancel();
      throw const FormatException('Could not open Intuit authorization.');
    }
    _connecting = true;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, _) => const Text('Could not load QuickBooks settings.'),
      builder: (_) => HMBFormList(
        children: [
          const Text('QuickBooks Online invoice export — preview'),
          const Text(
            'Requires your own Intuit developer app and registered callback. '
            'Live authorization and tax behaviour have not yet been verified. '
            'Exports are snapshots: payments, edits and voids '
            'are not synchronized. '
            'Existing Xero connections are unchanged.',
          ),
          Text(_connected ? 'Connected' : 'Not connected'),
          HMBTextField(controller: _client, labelText: 'Intuit client ID'),
          HMBTextField(
            controller: _secret,
            labelText: 'Client secret (blank keeps saved)',
            obscureText: true,
          ),
          HMBTextField(
            controller: _redirect,
            labelText: 'Registered redirect URI',
          ),
          if (_connecting)
            Text(_sandbox ? 'Sandbox company' : 'Live company')
          else
            HMBToggle(
              label: 'Sandbox (test company)',
              hint: 'Use a QuickBooks test company',
              initialValue: _sandbox,
              onToggled: (value) => setState(() => _sandbox = value),
            ),
          HMBTextField(
            controller: _item,
            labelText: 'QuickBooks product/service item ID',
          ),
          HMBToggle(
            label: 'US sales tax model',
            hint: 'Use US sales tax codes',
            initialValue: _us,
            onToggled: (value) => setState(() => _us = value),
          ),
          const Text(
            'Enter tax codes from the connected company. Every line must '
            'have explicit HMB tax metadata. Review exported tax before '
            'sending. The invoice currency is preserved; '
            'no currency conversion is performed.',
          ),
          HMBTextField(
            controller: _taxable,
            labelText: 'Taxable sales code ID',
          ),
          HMBTextField(
            controller: _exempt,
            labelText: 'Zero-tax sales code ID',
          ),
          if (_us)
            HMBTextField(
              controller: _transactionTax,
              labelText: 'US transaction tax code ID',
            ),
          HMBButtonSecondary(
            label: 'Save settings',
            hint: 'Save without contacting QuickBooks',
            onPressed: () => _run(_save),
          ),
          HMBButtonPrimary(
            label: 'Connect to QuickBooks',
            hint: 'Open Intuit authorization',
            onPressed: () => _run(_connect),
          ),
          if (_connecting) ...[
            const Text(
              'After approving access, copy the final callback URL from '
              'your browser and paste it here. Treat this URL as a secret; '
              'do not '
              'share it or use an untrusted callback service.',
            ),
            HMBTextField(
              controller: _callback,
              labelText: 'Authorization callback URL',
              obscureText: true,
            ),
            HMBButtonPrimary(
              label: 'Complete connection',
              hint: 'Validate the callback and store tokens securely',
              onPressed: () => _run(() async {
                try {
                  await _auth.complete(_callback.text);
                  _connected = true;
                } finally {
                  _callback.clear();
                  _connecting = false;
                }
              }),
            ),
          ],
          if (_connected)
            HMBButtonSecondary(
              label: 'Disconnect locally',
              hint: 'Remove saved tokens; revoke access separately in Intuit',
              onPressed: () => _run(() async {
                final secrets = await DaoSystem().getQuickBooksCredentials();
                await DaoSystem().updateQuickBooksCredentials(
                  QuickBooksCredentials(clientSecret: secrets.clientSecret),
                );
                _connected = false;
              }),
            ),
        ],
      ),
    ),
  );
}
