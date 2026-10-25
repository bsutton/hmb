import 'package:material_ui/material_ui.dart';

import '../../dao/billing_service.dart';
import '../../entity/entity.g.dart';
import '../../util/dart/local_date.dart';
import '../../util/dart/money_ex.dart';
import '../widgets/layout/layout.g.dart';
import '../widgets/select/hmb_droplist.dart';
import '../widgets/widgets.g.dart';

/// Invoice presentation and delivery choices, after charges have been reviewed.
class InvoiceOptionsScreen extends StatefulWidget {
  final BillingPreview preview;
  final Set<String> selected;
  final bool allowEarlyBilling;

  const InvoiceOptionsScreen({
    required this.preview,
    required this.selected,
    required this.allowEarlyBilling,
    super.key,
  });

  @override
  State<InvoiceOptionsScreen> createState() => _InvoiceOptionsScreenState();
}

class _InvoiceOptionsScreenState extends State<InvoiceOptionsScreen> {
  late Contact? _contact = widget.preview.contacts
      .where((contact) => contact.id == widget.preview.defaultContactId)
      .firstOrNull;
  late LocalDate _dueDate = LocalDate.today().add(
    Duration(days: widget.preview.paymentTerms),
  );
  var _byTask = true;
  var _saving = false;
  String? _error;
  InvoicePlan? _pending;

  String get _total => widget.preview.candidates
      .where((charge) => widget.selected.contains(charge.key))
      .fold(MoneyEx.zero, (total, charge) => total + charge.amount)
      .toString();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prepare invoice')),
    body: HMBFormList(
      children: [
        Text(widget.preview.job.summary),
        Text('Bill to: ${widget.preview.billingCustomerName}'),
        HMBDroplist<Contact>(
          title: 'Bill to contact',
          items: (_) async => widget.preview.contacts,
          selectedItem: () async => _contact,
          format: (contact) => contact.fullname,
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
          onChanged: (value) => setState(() {
            _byTask = value;
            _pending = null;
          }),
        ),
        Text('Total: $_total'),
        if (_error != null) Text(_error!),
        HMBButtonPrimary(
          label: 'Create draft invoice',
          hint: 'Reserve the reviewed charges and create this invoice',
          onPressed: _saving || _contact == null ? null : _create,
        ),
      ],
    ),
  );

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      _pending ??= widget.preview.select(
        keys: widget.selected,
        contactId: _contact!.id,
        groupByTask: _byTask,
        allowEarlyBilling: widget.allowEarlyBilling,
        dueDate: _dueDate,
      );
      final invoice = await BlockingUI().runAndWait(
        () => BillingService().commit(_pending!),
      );
      if (mounted) {
        Navigator.of(context).pop(invoice);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
