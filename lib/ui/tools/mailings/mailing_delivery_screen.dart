/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../dao/dao_mailing_recipient.dart';
import '../../../entity/mailing_recipient.dart';
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

class _MailingDeliveryScreenState extends State<MailingDeliveryScreen> {
  final _recipientDao = DaoMailingRecipient();
  List<MailingRecipient> _recipients = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final recipients = await _recipientDao.getRouteReady(widget.mailingId);
    if (mounted) {
      setState(() {
        _recipients = recipients;
        _loading = false;
      });
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
    await _load();
  }

  Future<void> _undoLast() async {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final current = _current;
    final complete = _recipients
        .where(
          (recipient) =>
              recipient.deliveryStatus != MailingDeliveryStatus.pending,
        )
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Delivery')),
      body: Padding(
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
      ),
    );
  }
}
