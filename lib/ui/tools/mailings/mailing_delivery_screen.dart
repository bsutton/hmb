/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/customer.dart';
import '../../../entity/mailing_recipient.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_chip.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart';
import 'google_maps_route_service.dart';

class MailingDeliveryScreen extends StatefulWidget {
  final int mailingId;

  const MailingDeliveryScreen({required this.mailingId, super.key});

  @override
  State<MailingDeliveryScreen> createState() => _MailingDeliveryScreenState();
}

class _MailingDeliveryScreenState extends DeferredState<MailingDeliveryScreen> {
  final _recipientDao = DaoMailingRecipient();
  List<MailingRecipient> _recipients = [];
  final _undoActions = <Future<void> Function()>[];

  @override
  Future<void> asyncInitState() => _load(notify: false);

  Future<void> _load({bool notify = true}) async {
    final recipients = await _recipientDao.getRouteReady(widget.mailingId);
    _recipients = recipients;
    if (notify && mounted) {
      setState(() {});
    }
  }

  MailingRecipient? get _current => _recipients
      .where(
        (recipient) =>
            recipient.deliveryStatus == MailingDeliveryStatus.pending,
      )
      .firstOrNull;

  Future<void> _navigate() async {
    final current = _current;
    if (current == null) {
      HMBToast.info('All stops are complete.');
      return;
    }
    await GoogleMapsRouteService().launchDirections(recipients: [current]);
  }

  Future<void> _setStatus(MailingDeliveryStatus status) async {
    final current = _current;
    if (current == null) {
      return;
    }
    await _recipientDao.updateDeliveryStatus(current, status);
    _undoActions.add(
      () => _recipientDao.updateDeliveryStatus(
        current,
        MailingDeliveryStatus.pending,
      ),
    );
    await _load();
  }

  Future<void> _undoLast() async {
    if (_undoActions.isNotEmpty) {
      await _undoActions.removeLast()();
      await _load();
      return;
    }
    final completed = _recipients
        .where(
          (recipient) =>
              recipient.deliveryStatus != MailingDeliveryStatus.pending,
        )
        .toList();
    if (completed.isEmpty) {
      return;
    }
    final last = completed.last;
    await _recipientDao.updateDeliveryStatus(
      last,
      MailingDeliveryStatus.pending,
    );
    await _load();
  }

  Future<void> _markNoMail() async {
    final current = _current;
    if (current == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Mail'),
        content: Text(
          'Skip this delivery and exclude ${current.customerName} from '
          'future mailings?',
        ),
        actions: [
          HMBButton(
            label: 'Cancel',
            hint: 'Keep this recipient in the mailing',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButton(
            label: 'No Mail',
            hint: 'Skip this stop and exclude future mailings',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final change = await BlockingUI().runAndWait(
      label: 'Updating Recipient',
      () => markNoMailForDelivery(current),
    );
    if (change == null) {
      HMBToast.error('Unable to update this customer.');
      return;
    }
    _undoActions.add(change.undo);
    await _load();
    HMBToast.info('Customer excluded from future mailings.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delivery')),
    body: DeferredBuilder(this, builder: (_) => _buildBody(context)),
  );

  Widget _buildBody(BuildContext context) {
    final current = _current;
    final complete = _recipients
        .where(
          (recipient) =>
              recipient.deliveryStatus != MailingDeliveryStatus.pending,
        )
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBChip(label: '$complete of ${_recipients.length} complete'),
          const HMBSpacer(height: true),
          if (current == null)
            Expanded(
              child: Center(
                child: HMBColumn(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('All selected stops are complete.'),
                    HMBButton.withIcon(
                      label: 'Undo',
                      icon: const Icon(Icons.undo),
                      hint: 'Undo the last delivery action',
                      onPressed: () => unawaited(_undoLast()),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: HMBColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.contactName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(current.customerName),
                      if ((current.siteName ?? '').isNotEmpty)
                        Text(current.siteName!),
                      const HMBSpacer(height: true),
                      Text(current.address),
                      const HMBSpacer(height: true),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          HMBButton.withIcon(
                            label: 'Navigate',
                            icon: const Icon(Icons.navigation),
                            hint: 'Open Google Maps for this stop',
                            onPressed: () => unawaited(_navigate()),
                          ),
                          HMBButton.withIcon(
                            label: 'Delivered',
                            icon: const Icon(Icons.check),
                            hint: 'Mark this stop as delivered',
                            onPressed: () => unawaited(
                              _setStatus(MailingDeliveryStatus.delivered),
                            ),
                          ),
                          HMBButton.withIcon(
                            label: 'Skip',
                            icon: const Icon(Icons.skip_next),
                            hint: 'Skip this stop',
                            onPressed: () => unawaited(
                              _setStatus(MailingDeliveryStatus.skipped),
                            ),
                          ),
                          HMBButton.withIcon(
                            label: 'No Mail',
                            icon: const Icon(Icons.unsubscribe),
                            hint: 'Skip this stop and exclude future mailings',
                            onPressed: () => unawaited(_markNoMail()),
                          ),
                          HMBButton.withIcon(
                            label: 'Undo',
                            icon: const Icon(Icons.undo),
                            hint: 'Undo the last delivery action',
                            onPressed: () => unawaited(_undoLast()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DeliveryNoMailChange {
  final Customer previousCustomer;
  final MailingRecipient previousRecipient;

  const DeliveryNoMailChange({
    required this.previousCustomer,
    required this.previousRecipient,
  });

  Future<void> undo() async {
    await DaoCustomer().update(previousCustomer);
    await DaoMailingRecipient().updateDeliveryStatus(
      previousRecipient,
      MailingDeliveryStatus.pending,
    );
  }
}

Future<DeliveryNoMailChange?> markNoMailForDelivery(
  MailingRecipient recipient,
) async {
  final customerDao = DaoCustomer();
  final customer = await customerDao.getById(recipient.customerId);
  if (customer == null) {
    return null;
  }
  await customerDao.update(customer.copyWith(excludeFromMailings: true));
  try {
    await DaoMailingRecipient().updateDeliveryStatus(
      recipient,
      MailingDeliveryStatus.skipped,
    );
  } catch (_) {
    await customerDao.update(customer);
    rethrow;
  }
  return DeliveryNoMailChange(
    previousCustomer: customer,
    previousRecipient: recipient,
  );
}
