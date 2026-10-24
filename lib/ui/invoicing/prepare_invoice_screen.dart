import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/billing_service.dart';
import '../../dao/billing_waiver.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/format.dart';
import '../../util/dart/local_date.dart';
import '../../util/dart/money_ex.dart';
import '../crud/milestone/edit_milestone_payment.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';
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
  Contact? _contact;
  late LocalDate _dueDate;
  var _early = false;
  var _byTask = true;
  var _saving = false;
  String? _error;
  InvoicePlan? _pending;

  @override
  Future<void> asyncInitState() => BlockingUI().runAndWait(_load);

  Future<void> _load() async {
    _preview = await _service.preview(widget.jobId);
    _contact = _preview.contacts
        .where((c) => c.id == _preview.defaultContactId)
        .firstOrNull;
    _dueDate = LocalDate.today().add(Duration(days: _preview.paymentTerms));
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
    _pending = null;
    _error = null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prepare invoice')),
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
            Text('Bill to: ${_preview.billingCustomerName}'),
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
                      if (c.kind == 'quote')
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
                HMBDroplist<Contact>(
                  title: 'Bill to contact',
                  items: (_) async => _preview.contacts,
                  selectedItem: () async => _contact,
                  format: (c) => c.fullname,
                  onChanged: (contact) => setState(() {
                    _contact = contact;
                    _pending = null;
                  }),
                ),
                HMBDateTimeField(
                  label: 'Payment due',
                  initialDateTime: _dueDate.toDateTime(),
                  mode: HMBDateTimeFieldMode.dateOnly,
                  onChanged: (date) => setState(() {
                    _dueDate = LocalDate.fromDateTime(date);
                    _pending = null;
                  }),
                ),
                HMBSwitch(
                  labelText: 'Group labour by task',
                  initialValue: _byTask,
                  leadingSpace: false,
                  onChanged: (v) => setState(() {
                    _byTask = v;
                    _pending = null;
                  }),
                ),
                if (selected.any((c) => c.isFuture))
                  HMBSwitch(
                    labelText: 'Bill selected future milestones now',
                    initialValue: _early,
                    leadingSpace: false,
                    onChanged: (v) => setState(() {
                      _early = v;
                      _pending = null;
                    }),
                  ),
                Text(
                  'Total: $total',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (_preview.taxRate > 0)
                  Text('Included tax: ${_preview.includedTax(selected)}'),
              ],
            ),
            if (_error != null) Text(_error!),
            HMBButtonSecondary(
              label: 'Refresh charges',
              hint: 'Reload current billable work',
              onPressed: () async {
                await BlockingUI().runAndWait(_load);
                if (mounted) {
                  setState(() {});
                }
              },
            ),
            HMBButtonPrimary(
              label: 'Create draft invoice',
              hint: 'Reserve the selected charges and create this invoice',
              onPressed: _saving || _selected.isEmpty || _contact == null
                  ? null
                  : _create,
            ),
            HMBButtonSecondary(
              label: 'Waive selected charges',
              hint: 'Record why the selected charges will not be billed',
              onPressed: _saving || _selected.isEmpty ? null : _waive,
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
        '${charge.description} — ${charge.amount}'
        '${charge.isFuture ? ' (future milestone)' : ''}',
    initialValue: _selected.contains(charge.key),
    onChanged: (value) => setState(() {
      value ? _selected.add(charge.key) : _selected.remove(charge.key);
      _pending = null;
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
  }

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
            _pending = null;
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
        _contact = refreshed.contacts
            .where((contact) => contact.id == _contact?.id)
            .firstOrNull;
        _pending = null;
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

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      _pending ??= _preview.select(
        keys: _selected,
        contactId: _contact!.id,
        groupByTask: _byTask,
        allowEarlyBilling: _early,
        dueDate: _dueDate,
      );
      final invoice = await BlockingUI().runAndWait(
        () => _service.commit(_pending!),
      );
      if (mounted) {
        Navigator.of(context).pop(invoice);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
