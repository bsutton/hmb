import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_contact_role.dart';
import '../../../entity/contact.dart';
import '../../../entity/contact_role.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/widgets.g.dart';
import '../job/edit_job_screen.dart';
import '../job/job_edit_section.dart';
import 'contact_roles_screen.dart';

class ContactRoleUsageScreen extends StatefulWidget {
  final ContactRole role;
  const ContactRoleUsageScreen({required this.role, super.key});

  @override
  State<ContactRoleUsageScreen> createState() => _ContactRoleUsageScreenState();
}

class _ContactRoleUsageScreenState
    extends DeferredState<ContactRoleUsageScreen> {
  late ContactRoleUsage _usage;
  ContactRole? _replacement;

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    final usage = await BlockingUI().runAndWait(
      () => DaoContactRole().getUsage(widget.role.id),
    );
    if (mounted) {
      setState(() => _usage = usage);
    }
  }

  Future<void> _changeDefault(Contact contact) async {
    ContactRole? selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact.fullname.trim()),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact.bestEmail.isNotEmpty) Text(contact.bestEmail),
            const Text(
              'Change this contact’s default role. '
              'Existing job assignments are managed separately.',
            ),
            ContactRoleSelector(
              roleId: contact.defaultRoleId,
              required: true,
              onChanged: (role) => selected = role,
            ),
          ],
        ),
        actions: [
          HMBSaveCancelButtons(
            onCancel: () => Navigator.pop(context, false),
            onSave: () => Navigator.pop(context, selected != null),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await BlockingUI().runAndWait(() async {
        final current = await DaoContact().getById(contact.id);
        if (current != null) {
          current.defaultRoleId = selected!.id;
          await DaoContact().update(current);
        }
      });
      await _load();
    } catch (error) {
      HMBToast.error(error.toString());
    }
  }

  Future<void> _reassign() async {
    final target = _replacement;
    if (target == null || target.id == widget.role.id) {
      HMBToast.error('Select a different replacement role.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reassign all uses?'),
        content: Text(
          'Replace “${widget.role.name}” with “${target.name}” '
          'for all contact defaults and job assignments using this role. '
          'Currently this includes ${_usage.contacts.length} contact defaults '
          'and ${_usage.assignments.length} job assignments. '
          'The original role will remain available until you delete it.',
        ),
        actions: [
          HMBCancelButton(onPressed: () => Navigator.pop(context, false)),
          HMBButtonPrimary(
            label: 'Reassign',
            hint: 'Move all uses to the replacement role',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await BlockingUI().runAndWait(
        () => DaoContactRole().reassign(widget.role.id, target.id),
      );
      await _load();
      HMBToast.info('All uses moved to ${target.name}.');
    } catch (error) {
      HMBToast.error(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Usage: ${widget.role.name}',
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => const Text('Could not load role usage.'),
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Contact defaults: ${_usage.contacts.length} · '
            'Job assignments: ${_usage.assignments.length}',
          ),
          if (_usage.isEmpty)
            Text(
              widget.role.builtin
                  ? 'This standard role has no current uses.'
                  : 'This role has no current uses and can be deleted '
                        'from Role types.',
            )
          else ...[
            ContactRoleSelector(
              roleId: _replacement?.id,
              excludeRoleId: widget.role.id,
              title: 'Replacement role',
              onChanged: (role) => setState(() => _replacement = role),
            ),
            HMBButtonPrimary(
              label: 'Reassign all uses',
              hint: 'Review and move all uses to another role',
              onPressed: _reassign,
            ),
            const Text(
              'Existing identical assignments are combined. '
              'If a job has a conflicting Primary or Billing Contact, '
              'or the contact cannot bill for that customer, '
              'nothing is changed. Edit that job first.',
            ),
          ],
          const SizedBox(height: 16),
          const Text('Contacts using this default role'),
          for (final contact in _usage.contacts)
            ListTile(
              title: Text(contact.fullname.trim()),
              subtitle: Text(contact.bestEmail),
              trailing: const Icon(Icons.edit),
              onTap: () => _changeDefault(contact),
            ),
          const SizedBox(height: 16),
          const Text('Jobs using this role'),
          for (final assignment in _usage.assignments)
            ListTile(
              title: Text('#${assignment.job.id} ${assignment.job.summary}'),
              subtitle: Text(assignment.contact.fullname.trim()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => JobEditScreen(
                      job: assignment.job,
                      section: JobEditSection.parties,
                    ),
                  ),
                );
                await _load();
              },
            ),
        ],
      ),
    ),
  );
}
