import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../dao/billing_service.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/local_date.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';

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
            .where((candidate) => !candidate.isFuture)
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
                      HMBSwitch(
                        key: ValueKey(c.key),
                        leadingSpace: false,
                        labelText:
                            '${c.description} — ${c.amount}'
                            '${c.isFuture ? ' (future milestone)' : ''}',
                        initialValue: _selected.contains(c.key),
                        onChanged: (value) => setState(() {
                          value
                              ? _selected.add(c.key)
                              : _selected.remove(c.key);
                          _pending = null;
                        }),
                      ),
                  ],
                ),
            if (_preview.candidates.isEmpty)
              const Text('No charges are ready to invoice.'),
            for (final reason in _preview.blocked) Text(reason),
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
          ],
        );
      },
    ),
  );

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
