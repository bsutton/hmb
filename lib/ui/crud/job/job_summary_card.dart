import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/dao_job_party.dart';
import '../../../dao/job_billing_contact.dart';
import '../../../entity/entity.g.dart';
import '../../../entity/job_party.dart';
import '../../dialog/source_context.dart';
import '../../widgets/hmb_contact_actions.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/widgets.g.dart';
import 'job_edit_section.dart';

/// The former job edit card is now a summary with independently saved editors.
/// It deliberately does not contain the list card's dashlets.
class JobSummaryCard extends StatefulWidget {
  final Job job;
  final Future<void> Function(JobEditSection section) onEdit;
  final Future<void> Function() onActions;

  const JobSummaryCard({
    required this.job,
    required this.onEdit,
    required this.onActions,
    super.key,
  });
  @override
  State<JobSummaryCard> createState() => _JobSummaryCardState();
}

class _JobSummaryCardState extends DeferredState<JobSummaryCard> {
  Customer? _customer;
  Customer? _billTo;
  Customer? _referrer;
  Site? _site;
  List<JobParty> _parties = [];
  late ResolvedJobBillingContact _billing;
  var _notes = 0;
  var _attachments = 0;
  var _photos = 0;

  int get _contactCount =>
      _parties.map((party) => party.contact.id).toSet().length;

  @override
  Future<void> asyncInitState() async {
    await BlockingUI().runAndWait(() async {
      final job = widget.job;
      _customer = await DaoCustomer().getById(job.customerId);
      _billTo = await DaoCustomer().getById(job.billingCustomerId);
      _referrer = await DaoCustomer().getById(job.referrerCustomerId);
      _site = await DaoSite().getById(job.siteId);
      _parties = await DaoJobParty().getByJob(job.id);
      _billing = await resolveJobBillingContact(job);
      _notes = (await DaoActivity().getByJob(
        job.id,
        type: ActivityType.note,
      )).length;
      _attachments = (await DaoJobAttachment().getByJob(job.id)).length;
      final counts = await DatabaseHelper.instance.database.rawQuery(
        'SELECT COUNT(*) AS count FROM photo p '
        'JOIN task t ON t.id = p.parentId '
        'WHERE p.parentType = ? AND t.job_id = ?',
        ['task', job.id],
      );
      _photos = counts.single['count']! as int;
    });
  }

  Widget _section(JobEditSection section, Widget body, {String? title}) =>
      SurfaceCardWithActions(
        summary: true,
        padding: const EdgeInsets.all(16),
        title: title ?? section.title,
        body: body,
        actions: [
          HMBButtonSecondary(
            quiet: true,
            key: ValueKey('edit-job-section-${section.name}'),
            label: section == JobEditSection.parties
                ? 'Manage'
                : section == JobEditSection.billing
                ? 'Change'
                : section.immediate
                ? 'Open'
                : 'Edit',
            hint: 'Open ${section.title.toLowerCase()}',
            onPressed: () => widget.onEdit(section),
          ),
        ],
      );

  Widget _text(String value, String empty) => Text(
    value.trim().isEmpty ? empty : value,
    maxLines: 4,
    overflow: TextOverflow.ellipsis,
  );

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => const Text('Could not load job details.'),
    builder: (context) => HMBColumn(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          JobEditSection.summary,
          title: widget.job.summary,
          HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_customer?.name ?? 'No customer selected'),
              _text(widget.job.description, 'No description'),
            ],
          ),
        ),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Status:'),
              HMBChip(label: widget.job.status.displayName),
              HMBButtonPrimary(
                label: 'Job actions',
                hint: 'Perform a job action',
                onPressed: widget.onActions,
              ),
              HMBButtonSecondary(
                quiet: true,
                label: 'Schedule',
                hint: 'Manage job visits',
                onPressed: () => widget.onEdit(JobEditSection.schedule),
              ),
            ],
          ),
        ),
        _section(
          JobEditSection.site,
          _site == null
              ? const Text('No site selected')
              : HMBSiteText(label: '', site: _site, job: widget.job),
        ),
        _section(
          JobEditSection.parties,
          HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_referrer != null) Text('Referred by: ${_referrer!.name}'),
              if (_parties.isEmpty) const Text('No contacts assigned'),
              for (final party in _parties)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withSafeOpacity(0.12),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(party.contact.fullname.trim())),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              party.role.name,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      HMBContactActions(
                        sourceContext: SourceContext(
                          contact: party.contact,
                          job: widget.job,
                          customer: _customer,
                          site: _site,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                '$_contactCount ${_contactCount == 1 ? 'contact' : 'contacts'}'
                ' · ${_parties.length} '
                '${_parties.length == 1 ? 'role' : 'roles'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _section(
          JobEditSection.billing,
          HMBColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bill To customer'),
              Text(_billTo?.name ?? 'No customer selected'),
              const Divider(),
              const Text('Send invoices to'),
              Text(_billing.contact?.fullname.trim() ?? 'No billing contact'),
              if (_billing.source != JobBillingContactSource.explicit &&
                  _billing.contact != null)
                const HMBChip(label: 'Automatic'),
              Text(_billing.source.description),
              const Divider(),
              Text('Billing type: ${widget.job.billingType.display}'),
              Text('Hourly rate: ${widget.job.hourlyRate ?? 'Not set'}'),
              Text('Booking fee: ${widget.job.bookingFee ?? 'Not set'}'),
            ],
          ),
        ),
        _section(
          JobEditSection.internalNotes,
          _text(widget.job.internalNotes, 'No internal notes'),
        ),
        _section(
          JobEditSection.assumptions,
          _text(widget.job.assumption, 'No assumptions'),
        ),
        _section(JobEditSection.notes, Text('$_notes note(s)')),
        _section(
          JobEditSection.attachments,
          Text('$_attachments attachment(s)'),
        ),
        _section(JobEditSection.photos, Text('$_photos photo(s)')),
      ],
    ),
  );
}
