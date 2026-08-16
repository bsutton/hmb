/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';

import '../../../dao/dao_mailing.dart';
import '../../../dao/dao_mailing_recipient.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/mailing.dart';
import '../../../entity/mailing_recipient.dart';
import '../../../util/dart/measurement_type.dart';
import '../../dialog/email_dialog.dart';
import '../../widgets/hmb_button.dart';
import '../../widgets/hmb_chip.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/attachment_pdf_viewer.dart';
import 'label_layout.dart';
import 'list_custom_label_layout_screen.dart';
import 'mailing_label_pdf.dart';

enum _MailingLabelPrintOrder {
  route('Optimised route order'),
  contact('Contact name');

  const _MailingLabelPrintOrder(this.label);

  final String label;
}

class MailingLabelsScreen extends StatefulWidget {
  final int mailingId;

  const MailingLabelsScreen({required this.mailingId, super.key});

  @override
  State<MailingLabelsScreen> createState() => _MailingLabelsScreenState();
}

class _MailingLabelsScreenState extends State<MailingLabelsScreen> {
  final _mailingDao = DaoMailing();
  final _recipientDao = DaoMailingRecipient();
  final _usedLabelsController = TextEditingController(text: '0');

  Mailing? _mailing;
  late PreferredUnitSystem _unitSystem;
  List<LabelLayout> _layouts = [];
  List<MailingRecipient> _recipients = [];
  LabelLayout? _layout;
  _MailingLabelPrintOrder _printOrder = _MailingLabelPrintOrder.contact;
  var _printOrderInitialised = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _usedLabelsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var mailing = await _mailingDao.getById(widget.mailingId);
    final system = await DaoSystem().get();
    final layouts = await LabelLayout.availableForUnitSystem(
      system.preferredUnitSystem,
    );
    final layout = await LabelLayout.byId(
      mailing!.labelLayoutId,
      fallbackUnitSystem: system.preferredUnitSystem,
    );
    if (mailing.labelLayoutId != layout.id) {
      mailing = mailing.copyWith(labelLayoutId: layout.id);
      await _mailingDao.update(mailing);
    }
    final recipients = await _recipientDao.getByMailing(mailing.id);
    if (!mounted) {
      return;
    }
    final routeOrderAvailable = _hasCompleteRouteOrder(mailing, recipients);
    setState(() {
      _mailing = mailing;
      _unitSystem = system.preferredUnitSystem;
      _layouts = layouts;
      _recipients = recipients;
      _layout = layout;
      if (!_printOrderInitialised || !routeOrderAvailable) {
        _printOrder = routeOrderAvailable
            ? _MailingLabelPrintOrder.route
            : _MailingLabelPrintOrder.contact;
        _printOrderInitialised = true;
      }
      _loading = false;
    });
  }

  List<MailingRecipient> get _readyRecipients =>
      _recipients
          .where(
            (recipient) =>
                recipient.selected &&
                recipient.hasAddress &&
                !recipient.excluded,
          )
          .toList()
        ..sort(_comparePrintOrder);

  bool get _routeOrderAvailable =>
      _hasCompleteRouteOrder(_mailing, _recipients);

  static bool _hasCompleteRouteOrder(
    Mailing? mailing,
    List<MailingRecipient> recipients,
  ) {
    if (!(mailing?.routeOptimised ?? false)) {
      return false;
    }
    final ready = recipients.where(
      (recipient) =>
          recipient.selected && recipient.hasAddress && !recipient.excluded,
    );
    return ready.isNotEmpty &&
        ready.every(
          (recipient) =>
              recipient.routeBatch != null && recipient.routeOrder != null,
        );
  }

  int _comparePrintOrder(MailingRecipient a, MailingRecipient b) =>
      switch (_printOrder) {
        _MailingLabelPrintOrder.contact => _compareByContact(a, b),
        _MailingLabelPrintOrder.route => _compareByRoute(a, b),
      };

  int _compareByContact(MailingRecipient a, MailingRecipient b) {
    final contact = a.contactName.compareTo(b.contactName);
    if (contact != 0) {
      return contact;
    }
    return a.customerName.compareTo(b.customerName);
  }

  int _compareByRoute(MailingRecipient a, MailingRecipient b) {
    final aBatch = a.routeBatch;
    final bBatch = b.routeBatch;
    final aOrder = a.routeOrder;
    final bOrder = b.routeOrder;
    if (aBatch == null || aOrder == null) {
      return bBatch == null || bOrder == null ? _compareByContact(a, b) : 1;
    }
    if (bBatch == null || bOrder == null) {
      return -1;
    }
    final batch = aBatch.compareTo(bBatch);
    if (batch != 0) {
      return batch;
    }
    final order = aOrder.compareTo(bOrder);
    if (order != 0) {
      return order;
    }
    return _compareByContact(a, b);
  }

  int get _usedLabels {
    final layout = _layout;
    if (layout == null) {
      return 0;
    }
    return (int.tryParse(_usedLabelsController.text) ?? 0).clamp(
      0,
      layout.labelsPerPage - 1,
    );
  }

  Future<void> _setLayout(LabelLayout layout) async {
    final mailing = _mailing!;
    final updated = mailing.copyWith(labelLayoutId: layout.id);
    await _mailingDao.update(updated);
    if (mounted) {
      setState(() {
        _mailing = updated;
        _layout = layout;
      });
    }
  }

  Future<void> _previewLabels() async {
    final mailing = _mailing!;
    final layout = _layout!;
    final ready = _readyRecipients;
    if (ready.isEmpty) {
      HMBToast.error('No selected recipients have a complete address.');
      return;
    }
    final bytes = await buildMailingLabelPdfBytes(
      recipients: ready,
      layout: layout,
      skipLabels: _usedLabels,
    );
    final directory = await Directory.systemTemp.createTemp(
      'hmb-mailing-labels-',
    );
    final file = File(p.join(directory.path, '${mailing.id}-labels.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) {
      return;
    }
    await AttachmentPdfViewer.show(
      context: context,
      filePath: file.path,
      title: '${mailing.name} Labels',
    );
  }

  Future<void> _printLabels() async {
    final mailing = _mailing!;
    final layout = _layout!;
    final ready = _readyRecipients;
    if (ready.isEmpty) {
      HMBToast.error('No selected recipients have a complete address.');
      return;
    }
    await Printing.layoutPdf(
      name: '${mailing.name} labels',
      format: layout.pageFormat,
      onLayout: (_) => buildMailingLabelPdfBytes(
        recipients: ready,
        layout: layout,
        skipLabels: _usedLabels,
      ),
    );
  }

  Future<void> _emailLabels() async {
    final mailing = _mailing!;
    final layout = _layout!;
    final ready = _readyRecipients;
    if (ready.isEmpty) {
      HMBToast.error('No selected recipients have a complete address.');
      return;
    }

    final system = await DaoSystem().get();
    final file = await generateMailingLabelPdf(
      mailing: mailing,
      recipients: ready,
      layout: layout,
      skipLabels: _usedLabels,
    );
    if (!mounted) {
      return;
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => EmailDialog(
        preferredRecipient: system.emailAddress ?? '',
        emailRecipients: const [],
        subject: '${mailing.name} mailing labels',
        body: 'Please find the mailing labels PDF attached.',
        attachmentPaths: [file.path],
      ),
    );
  }

  Future<void> _manageCustomLabels() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomLabelLayoutListScreen(unitSystem: _unitSystem),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _mailing == null || _layout == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Print Mailing Labels')),
      body: _buildSetupTab(),
    );
  }

  Widget _buildSetupTab() {
    final layout = _layout!;
    final ready = _readyRecipients.length;
    final selected = _recipients
        .where((recipient) => recipient.selected && !recipient.excluded)
        .length;
    final invalid = _recipients
        .where(
          (recipient) =>
              recipient.selected &&
              !recipient.hasAddress &&
              !recipient.excluded,
        )
        .length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HMBChip(label: '$selected selected'),
              HMBChip(label: '$ready printable'),
              HMBChip(label: '$invalid invalid address'),
            ],
          ),
          const HMBSpacer(height: true),
          DropdownButtonFormField<LabelLayout>(
            initialValue: layout,
            decoration: const InputDecoration(
              labelText: 'Label layout',
              border: OutlineInputBorder(),
            ),
            items: _layouts
                .map(
                  (layout) =>
                      DropdownMenuItem(value: layout, child: Text(layout.name)),
                )
                .toList(),
            onChanged: (layout) {
              if (layout != null) {
                unawaited(_setLayout(layout));
              }
            },
          ),
          const HMBSpacer(height: true),
          Align(
            alignment: Alignment.centerLeft,
            child: HMBButton.withIcon(
              label: 'Manage Custom Labels',
              icon: const Icon(Icons.settings),
              hint: 'Manage custom label layouts',
              onPressed: () => unawaited(_manageCustomLabels()),
            ),
          ),
          const HMBSpacer(height: true),
          DropdownButtonFormField<_MailingLabelPrintOrder>(
            initialValue: _printOrder,
            decoration: InputDecoration(
              labelText: 'Print order',
              helperText: _routeOrderAvailable
                  ? 'Use route order when delivering labels in person.'
                  : 'Optimise the route first to print labels '
                        'in delivery order.',
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: _MailingLabelPrintOrder.route,
                enabled: _routeOrderAvailable,
                child: Text(_MailingLabelPrintOrder.route.label),
              ),
              DropdownMenuItem(
                value: _MailingLabelPrintOrder.contact,
                child: Text(_MailingLabelPrintOrder.contact.label),
              ),
            ],
            onChanged: (order) {
              if (order != null) {
                setState(() => _printOrder = order);
              }
            },
          ),
          const HMBSpacer(height: true),
          TextField(
            controller: _usedLabelsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Used labels on first sheet',
              helperText: 'Use this when printing onto a partly used sheet.',
              border: const OutlineInputBorder(),
              suffixText: 'of ${layout.labelsPerPage - 1}',
            ),
          ),
          const HMBSpacer(height: true),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HMBButton.withIcon(
                label: 'Preview',
                icon: const Icon(Icons.picture_as_pdf),
                hint: 'Preview mailing labels',
                onPressed: () => unawaited(_previewLabels()),
              ),
              HMBButton.withIcon(
                label: 'Print',
                icon: const Icon(Icons.print),
                hint: 'Print mailing labels',
                onPressed: () => unawaited(_printLabels()),
              ),
              HMBButton.withIcon(
                label: 'Email PDF',
                icon: const Icon(Icons.email_outlined),
                hint: 'Email the mailing labels for printing elsewhere',
                onPressed: () => unawaited(_emailLabels()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
