import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/billing_service.dart';
import '../../dao/billing_waiver.dart';
import '../../dao/dao_job.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/dart/money_ex.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/fields/hmb_money_editing_controller.dart';
import '../widgets/fields/hmb_money_field.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';
import 'invoice_options_screen.dart';
import 'waive_charges_dialog.dart';

class PrepareInvoiceScreen extends StatefulWidget {
  final int jobId;
  final int? milestoneId;
  final int? taskId;
  const PrepareInvoiceScreen({
    required this.jobId,
    this.milestoneId,
    this.taskId,
    super.key,
  });
  @override
  State<PrepareInvoiceScreen> createState() => _PrepareInvoiceScreenState();
}

class _PrepareInvoiceScreenState extends DeferredState<PrepareInvoiceScreen> {
  final _service = BillingService();
  late BillingPreview _preview;
  final _selected = <String>{};
  final _bookingFee = HMBMoneyEditingController();
  var _savedFeeText = '';
  late BillingType _billingType;
  var _early = false;
  var _saving = false;
  String? _error;
  var _loaded = false;
  var _waiverMode = false;
  final _invoiceSelection = <String>{};

  @override
  Future<void> asyncInitState() => BlockingUI().runAndWait(_load);

  Future<void> _load() async {
    final previousKeys = _loaded
        ? _preview.candidates.map((charge) => charge.key).toSet()
        : <String>{};
    _preview = await _service.preview(widget.jobId);
    _billingType = _preview.job.billingType;
    _bookingFee.money =
        _preview.effectiveBookingFee ?? _preview.job.bookingFee ?? MoneyEx.zero;
    _savedFeeText = _bookingFee.text;
    if (_loaded) {
      final available = _preview.candidates.map((c) => c.key).toSet();
      _selected.removeWhere((key) => !available.contains(key));
      if (!_waiverMode) {
        _selected.addAll(
          _preview.candidates
              .where(
                (charge) =>
                    !previousKeys.contains(charge.key) &&
                    !charge.isFuture &&
                    charge.kind != 'quote',
              )
              .map((charge) => charge.key),
        );
      }
      _error = null;
      return;
    }
    _loaded = true;
    _selected.clear();
    if (widget.milestoneId != null) {
      final key = 'milestone:${widget.milestoneId}';
      if (_preview.candidates.any((c) => c.key == key)) {
        _selected.add(key);
      }
    } else if (widget.taskId != null) {
      _selected.addAll(
        _preview.candidates
            .where((candidate) => candidate.taskId == widget.taskId)
            .map((candidate) => candidate.key),
      );
    } else {
      _selected.addAll(
        _preview.candidates
            .where(
              (candidate) => !candidate.isFuture && candidate.kind != 'quote',
            )
            .map((candidate) => candidate.key),
      );
    }
    _error = null;
  }

  @override
  void dispose() {
    _bookingFee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review charges')),
    body: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => Text('Unable to load billing: $error'),
      builder: (_) {
        final selected = _preview.candidates.where(
          (c) => _selected.contains(c.key),
        );
        final total = selected.fold(MoneyEx.zero, (sum, c) => sum + c.amount);
        return HMBFormList(
          children: [
            Text(
              _preview.job.summary,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_waiverMode)
              HMBFormSection(
                children: [
                  HMBDroplist<BillingType>(
                    title: 'Job billing type',
                    items: (_) async => BillingType.values,
                    selectedItem: () async => _billingType,
                    format: (type) => type.display,
                    onChanged: (type) {
                      if (type != null) {
                        setState(() => _billingType = type);
                      }
                    },
                  ),
                  const Text('Existing tasks keep their billing type.'),
                  for (final quote in _preview.bookingFeeQuotes.entries)
                    Text(
                      quote.value
                          ? 'Booking fee: invoiced with quote #${quote.key}'
                          : 'Booking fee: included in quote #${quote.key}',
                    ),
                  if (_preview.job.bookingFeeInvoiced)
                    const Text('Booking fee: invoiced separately'),
                  if (!_preview.job.bookingFeeInvoiced &&
                      _preview.bookingFeeQuotes.isEmpty)
                    HMBMoneyField(
                      controller: _bookingFee,
                      labelText: 'Booking fee',
                      fieldName: 'booking fee',
                      nonZero: false,
                    ),
                  HMBButtonSecondary(
                    label: 'Save changes',
                    hint: 'Save job billing settings and recalculate charges',
                    onPressed: _saving ? null : _saveChanges,
                  ),
                ],
              ),
            if (_waiverMode)
              const Text(
                'Select charges to waive. These charges will not be invoiced.',
              )
            else
              const Text('Select charges to include in the invoice.'),
            for (final section in [
              'Fixed payments',
              'Actual work',
              'Booking fee',
            ])
              if (_preview.candidates.any((c) => _section(c) == section))
                HMBFormSection(
                  children: [
                    Text(
                      section,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final c in _preview.candidates.where(
                      (c) => _section(c) == section,
                    ))
                      if (c.kind == 'quote' && !_waiverMode)
                        _fixedPaymentChoice(c)
                      else
                        _chargeSwitch(c),
                  ],
                ),
            if (_preview.candidates.isEmpty)
              const Text('No charges are ready to invoice.'),
            for (final reason in _preview.blocked) Text(reason),
            if (_preview.waivers.isNotEmpty)
              ExpansionTile(
                title: const Text('Waived charges'),
                children: [
                  for (final waiver in _preview.waivers) _waiverDetails(waiver),
                ],
              ),
            HMBFormSection(
              children: [
                if (!_waiverMode && selected.any((c) => c.isFuture))
                  HMBSwitch(
                    labelText: 'Bill selected future milestones now',
                    initialValue: _early,
                    leadingSpace: false,
                    onChanged: (v) => setState(() {
                      _early = v;
                    }),
                  ),
                Text(
                  _waiverMode
                      ? 'Selected to waive: ${selected.length} — $total'
                      : 'Total: $total',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_preview.taxRate > 0)
                  Text('Included tax: ${_preview.includedTax(selected)}'),
              ],
            ),
            if (_error != null) Text(_error!),
            if (!_waiverMode)
              HMBButtonPrimary(
                label: 'Continue to invoice',
                hint: 'Save changes and choose invoice details',
                onPressed: _saving || _selected.isEmpty ? null : _create,
              ),
            if (_waiverMode) ...[
              HMBButtonPrimary(
                label: 'Waive ${selected.length} selected charges',
                hint: 'Review the charges and give a reason before waiving',
                onPressed: _saving || _selected.isEmpty ? null : _waive,
              ),
              HMBButtonSecondary(
                label: 'Cancel waiver',
                hint: 'Return to invoice selection without waiving charges',
                onPressed: _saving ? null : _exitWaiverMode,
              ),
            ] else
              HMBButtonSecondary(
                label: 'Choose charges to waive',
                hint: 'Select charges separately from the invoice selection',
                onPressed: _saving
                    ? null
                    : () async {
                        if (!await _saveChanges() || !mounted) {
                          return;
                        }
                        setState(() {
                          _invoiceSelection
                            ..clear()
                            ..addAll(_selected);
                          _selected.clear();
                          _waiverMode = true;
                        });
                      },
              ),
          ],
        );
      },
    ),
  );

  Widget _chargeSwitch(BillingCandidate charge) => HMBSwitch(
    key: ValueKey(charge.key),
    leadingSpace: false,
    labelText:
        '${_waiverMode ? 'Waive: ' : ''}'
        '${charge.description} — ${charge.amount}'
        '${charge.isFuture ? ' (future milestone)' : ''}',
    initialValue: _selected.contains(charge.key),
    onChanged: (value) => setState(() {
      value ? _selected.add(charge.key) : _selected.remove(charge.key);
    }),
  );

  Widget _waiverDetails(BillingWaiver waiver) => HMBFormSection(
    children: [
      Text('${waiver.description} — ${waiver.amount}'),
      Text(
        'Waived ${formatDate(waiver.waivedDate, format: 'j M Y')}: '
        '${waiver.reason}',
      ),
      if (waiver.restoredDate == null &&
          _preview.candidates.any(
            (charge) =>
                charge.key == waiver.sourceKey &&
                charge.waiverHash != waiver.sourceHash,
          ))
        const Text('This work has changed. The updated charge needs review.'),
      if (waiver.restoredDate != null)
        Text('Restored ${formatDate(waiver.restoredDate!, format: 'j M Y')}')
      else
        HMBButtonSecondary(
          label: 'Restore charge',
          hint: 'Offer this charge for invoicing again',
          onPressed: _saving ? null : () => _restore(waiver),
        ),
    ],
  );

  Future<void> _waive() async {
    final charges = _preview.candidates
        .where((charge) => _selected.contains(charge.key))
        .toList();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => WaiveChargesDialog(charges: charges),
    );
    if (reason == null || !mounted) {
      return;
    }
    await _changeWaiver(
      () => _service.waiveCharges(
        preview: _preview,
        keys: charges.map((charge) => charge.key),
        reason: reason,
      ),
    );
    if (mounted && _error == null) {
      _exitWaiverMode();
    }
  }

  void _exitWaiverMode() => setState(() {
    _waiverMode = false;
    final available = _preview.candidates.map((c) => c.key).toSet();
    _selected
      ..clear()
      ..addAll(_invoiceSelection.where(available.contains));
  });

  Future<void> _restore(BillingWaiver waiver) => _changeWaiver(
    () => _service.restoreWaiver(jobId: widget.jobId, waiverId: waiver.id),
  );

  Future<void> _changeWaiver(Future<void> Function() change) async {
    setState(() => _saving = true);
    try {
      await BlockingUI().runAndWait(() async {
        await change();
        await _load();
      });
    } catch (error) {
      _error = error.toString();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _fixedPaymentChoice(BillingCandidate charge) => HMBFormSection(
    children: [
      Text('${charge.description} — ${charge.amount}'),
      const Text('How will this fixed price be billed?'),
      if (_selected.contains(charge.key))
        _chargeSwitch(charge)
      else
        HMBButtonSecondary(
          label: 'Bill in full',
          hint: 'Include the full agreed price in this invoice',
          onPressed: () => setState(() {
            _selected.add(charge.key);
          }),
        ),
      HMBButtonSecondary(
        label: 'Split into milestones',
        hint: 'Schedule progress payments for this agreed price',
        onPressed: () => _editSchedule(charge.quoteId!),
      ),
    ],
  );

  Future<void> _editSchedule(int quoteId) async {
    if (!await _saveChanges() || !mounted) {
      return;
    }
    final selectedMilestone = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            EditMilestonesScreen(quoteId: quoteId, returnToPreparation: true),
      ),
    );
    if (!mounted) {
      return;
    }
    try {
      final refreshed = await BlockingUI().runAndWait(
        () => _service.preview(widget.jobId),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = refreshed;
        final available = refreshed.candidates.map((c) => c.key).toSet();
        _selected.removeWhere((key) => !available.contains(key));
        for (final charge in refreshed.candidates) {
          if (charge.kind == 'milestone' &&
              charge.quoteId == quoteId &&
              charge.sourceId == selectedMilestone) {
            _selected.add(charge.key);
          }
        }
        _error = null;
      });
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _error = 'Unable to refresh charges: $error');
      }
    }
  }

  String _section(BillingCandidate c) => switch (c.kind) {
    'milestone' || 'quote' || 'task_scope' => 'Fixed payments',
    'booking_fee' => 'Booking fee',
    _ => 'Actual work',
  };

  Future<bool> _saveChanges() async {
    setState(() => _saving = true);
    try {
      final fee = _bookingFee.text.trim().isEmpty
          ? MoneyEx.zero
          : _bookingFee.money;
      if (fee == null || fee < MoneyEx.zero) {
        throw const FormatException('Enter a valid, non-negative booking fee.');
      }
      await BlockingUI().runAndWait(() async {
        final job = await DaoJob().getById(widget.jobId);
        if (job == null) {
          throw StateError('This job no longer exists.');
        }
        final feeChanged =
            !job.bookingFeeInvoiced &&
            _preview.bookingFeeQuotes.isEmpty &&
            _bookingFee.text != _savedFeeText;
        if (job.billingType != _billingType || feeChanged) {
          job.billingType = _billingType;
          if (feeChanged) {
            job.bookingFee = fee;
          }
          await DaoJob().update(job);
        }
        await _load();
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _create() async {
    if (!await _saveChanges() || !mounted || _selected.isEmpty) {
      return;
    }
    final invoice = await Navigator.of(context).push<Invoice>(
      MaterialPageRoute(
        builder: (_) => InvoiceOptionsScreen(
          preview: _preview,
          selected: Set.of(_selected),
          allowEarlyBilling: _early,
        ),
      ),
    );
    if (invoice != null && mounted) {
      Navigator.of(context).pop(invoice);
    }
  }
}
