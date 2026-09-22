import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/dao_job_party.dart';
import '../../../dao/join_adaptors/join_adaptor_customer_contact.dart';
import '../../../entity/entity.g.dart';
import '../../../entity/job_party.dart';
import '../../dialog/source_context.dart';
import '../../widgets/hmb_contact_actions.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/widgets.g.dart';
import '../contact/contact_roles_screen.dart';
import '../contact/edit_contact_screen.dart';

class JobPartiesScreen extends StatefulWidget {
  final Job job;
  final Future<void> Function() editCustomers;

  const JobPartiesScreen({
    required this.job,
    required this.editCustomers,
    super.key,
  });
  @override
  State<JobPartiesScreen> createState() => _JobPartiesScreenState();
}

class _JobPartiesScreenState extends DeferredState<JobPartiesScreen> {
  List<JobParty> _parties = [];
  Job? _job;
  Customer? _customer;
  Customer? _referrer;
  Site? _site;

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    await BlockingUI().runAndWait(() async {
      _job = await DaoJob().getById(widget.job.id);
      _customer = await DaoCustomer().getById(_job?.customerId);
      _referrer = await DaoCustomer().getById(_job?.referrerCustomerId);
      _site = await DaoSite().getById(_job?.siteId);
      _parties = await DaoJobParty().getByJob(widget.job.id);
    });
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _edit([JobParty? party]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PartyAssignmentEditor(job: _job!, party: party),
      ),
    );
    await _load();
  }

  Future<void> _editReferrer() async {
    var selected = _referrer;
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referring business'),
        scrollable: true,
        content: Form(
          key: form,
          child: HMBDroplist<Customer>(
            title: 'Referring customer',
            selectedItem: () async => selected,
            items: (filter) => DaoCustomer().getByFilter(filter),
            format: (customer) => customer.name,
            onChanged: (customer) => selected = customer,
          ),
        ),
        actions: [
          HMBButtonSecondary(
            label: 'Cancel',
            hint: 'Keep the current referring business',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButtonPrimary(
            label: 'Save',
            hint: 'Save the referring business without changing billing',
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && selected != null) {
      await _saveReferrer(selected!.id);
    }
  }

  Future<void> _saveReferrer(int? customerId) async {
    try {
      await BlockingUI().runAndWait(
        () => DaoJob().setReferringCustomer(widget.job.id, customerId),
      );
      await _load();
    } catch (error) {
      HMBToast.error(error.toString());
    }
  }

  Future<void> _removeReferrer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove referring business?'),
        content: Text(
          'Remove ${_referrer!.name} as the referring business? '
          'The customer record and billing settings will not change.',
        ),
        actions: [
          HMBButtonSecondary(
            label: 'Cancel',
            hint: 'Keep the referring business',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButtonPrimary(
            label: 'Remove',
            hint: 'Remove the referral only',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _saveReferrer(null);
    }
  }

  Future<void> _remove(JobParty party) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove job party?'),
        content: Text(
          'Remove ${party.contact.fullname.trim()} as '
          '${party.role.name}? The contact will not be deleted.',
        ),
        actions: [
          HMBButtonSecondary(
            label: 'Cancel',
            hint: 'Keep assignment',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButtonPrimary(
            label: 'Remove',
            hint: 'Remove this assignment only',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await BlockingUI().runAndWait(
        () => DaoJobParty().delete(widget.job.id, party.id),
      );
      await _load();
    } catch (error) {
      HMBToast.error(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Job parties',
    subdued: true,
    maxContentWidth: 800,
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => const Text('Could not load parties.'),
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.job.summary,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SurfaceCardWithActions(
            summary: true,
            padding: const EdgeInsets.all(16),
            title: 'Customer',
            actions: [
              HMBButtonSecondary(
                quiet: true,
                label: 'Change',
                hint: 'Change the job customer',
                onPressed: () async {
                  await widget.editCustomers();
                  await _load();
                },
              ),
            ],
            body: HMBColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(_customer?.name ?? 'Not selected')],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Job parties',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              HMBButtonPrimary(
                label: 'Add party',
                hint: 'Assign a contact and role',
                onPressed: _job == null ? null : _edit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_referrer != null)
            Surface(
              padding: EdgeInsets.zero,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(_referrer!.name),
                subtitle: const Text('Referrer · Customer/business'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit referring business',
                      icon: const Icon(Icons.edit),
                      onPressed: _editReferrer,
                    ),
                    IconButton(
                      tooltip: 'Remove referring business',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _removeReferrer,
                    ),
                  ],
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: HMBButtonSecondary(
                quiet: true,
                label: 'Add referring business',
                hint: 'Choose the customer or business that referred this job',
                onPressed: _job == null ? null : _editReferrer,
              ),
            ),
          if (_parties.isEmpty) const Text('No contacts assigned.'),
          for (final party in _parties)
            Surface(
              padding: EdgeInsets.zero,
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text(party.contact.fullname.trim()),
                    subtitle: Text(party.role.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit ${party.role.name}',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _edit(party),
                        ),
                        IconButton(
                          tooltip: 'Remove ${party.role.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(party),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: HMBContactActions(
                      sourceContext: SourceContext(
                        contact: party.contact,
                        job: _job,
                        customer: _customer,
                        site: _site,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Each row assigns one role. A contact may have several roles.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: HMBButtonSecondary(
              quiet: true,
              label: 'Manage role types',
              hint: 'View standard roles and manage custom roles',
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const ContactRolesScreen()),
                );
                await _load();
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PartyAssignmentEditor extends StatefulWidget {
  final Job job;
  final JobParty? party;
  const _PartyAssignmentEditor({required this.job, this.party});
  @override
  State<_PartyAssignmentEditor> createState() => _PartyAssignmentEditorState();
}

class _PartyAssignmentEditorState extends State<_PartyAssignmentEditor> {
  final _form = GlobalKey<FormState>();
  Contact? _contact;
  int? _roleId;
  var _roleChosen = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.party?.contact;
    _roleId = widget.party?.role.id;
    _roleChosen = widget.party != null;
  }

  void _selectContact(Contact? contact) {
    setState(() {
      _contact = contact;
      if (!_roleChosen) {
        _roleId = contact?.defaultRoleId;
      }
    });
  }

  Future<void> _createContact() async {
    final customer = await BlockingUI().runAndWait(
      () => DaoCustomer().getById(widget.job.customerId),
    );
    if (!mounted) {
      return;
    }
    if (customer == null) {
      HMBToast.error('Select a job customer before creating a contact.');
      return;
    }
    final contact = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) => ContactEditScreen<Customer>(
          parent: customer,
          daoJoin: JoinAdaptorCustomerContact(),
        ),
      ),
    );
    if (mounted && contact != null) {
      _selectContact(contact);
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = await BlockingUI().runAndWait(
        () => DaoJobParty().getByJob(widget.job.id),
      );
      if (!mounted) {
        return;
      }
      final conflict = existing
          .where(
            (party) =>
                party.role.id == _roleId &&
                party.role.singlePerJob &&
                party.id != widget.party?.id,
          )
          .firstOrNull;
      var replace = false;
      if (conflict != null) {
        replace =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Replace ${conflict.role.name}?'),
                content: Text(
                  'Replace ${conflict.contact.fullname.trim()} with '
                  '${_contact!.fullname.trim()} for this job?',
                ),
                actions: [
                  HMBButtonSecondary(
                    label: 'Cancel',
                    hint: 'Keep existing assignment',
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  HMBButtonPrimary(
                    label: 'Replace',
                    hint: 'Replace this job role',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ) ??
            false;
        if (!replace || !mounted) {
          return;
        }
      }
      await BlockingUI().runAndWait(
        () => DaoJobParty().save(
          jobId: widget.job.id,
          contactId: _contact!.id,
          roleId: _roleId!,
          assignmentId: widget.party?.id,
          replaceSingleton: replace,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      HMBToast.error(
        error.toString().contains('UNIQUE')
            ? 'That contact already has this role on the job.'
            : error.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: widget.party == null ? 'Add party' : 'Edit party',
    subdued: true,
    maxContentWidth: 600,
    child: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HMBDroplist<Contact>(
            title: 'Contact',
            selectedItem: () async => _contact,
            items: (filter) async => (await DaoContact().getAll())
                .where(
                  (contact) => '${contact.fullname} ${contact.bestEmail}'
                      .toLowerCase()
                      .contains((filter ?? '').toLowerCase()),
                )
                .toList(),
            format: (contact) => contact.fullname.trim(),
            onChanged: _selectContact,
            onAdd: _createContact,
          ),
          const SizedBox(height: 12),
          ContactRoleSelector(
            roleId: _roleId,
            required: true,
            title: 'Role on this job',
            onChanged: (role) => setState(() {
              _roleId = role?.id;
              _roleChosen = true;
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            'The contact’s default role is a suggestion. '
            'Changing this assignment only affects this job.',
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            children: [
              HMBButtonSecondary(
                quiet: true,
                label: 'Cancel',
                hint: 'Discard assignment changes',
                onPressed: () => Navigator.pop(context),
              ),
              HMBButtonPrimary(
                label: 'Save',
                hint: 'Save this assignment',
                enabled: !_saving,
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
