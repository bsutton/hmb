import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao_contact_role.dart';
import '../../../entity/contact_role.dart';
import '../../widgets/fields/hmb_text_field.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/select/hmb_droplist.dart';
import '../../widgets/widgets.g.dart';

class ContactRoleSelector extends StatelessWidget {
  final int? roleId;
  final ValueChanged<ContactRole?> onChanged;
  final bool required;
  final String title;

  const ContactRoleSelector({
    required this.roleId,
    required this.onChanged,
    this.required = false,
    this.title = 'Default role',
    super.key,
  });

  @override
  Widget build(BuildContext context) => HMBDroplist<ContactRole>(
    title: title,
    required: required,
    selectedItem: () => DaoContactRole().getById(roleId),
    items: (filter) async => (await DaoContactRole().getAll())
        .where(
          (role) =>
              role.name.toLowerCase().contains((filter ?? '').toLowerCase()),
        )
        .toList(),
    format: (role) => role.name,
    onChanged: onChanged,
  );
}

class ContactRolesScreen extends StatefulWidget {
  const ContactRolesScreen({super.key});
  @override
  State<ContactRolesScreen> createState() => _ContactRolesScreenState();
}

class _ContactRolesScreenState extends DeferredState<ContactRolesScreen> {
  List<ContactRole> _roles = [];

  @override
  Future<void> asyncInitState() => _load();

  Future<void> _load() async {
    final roles = await BlockingUI().runAndWait(DaoContactRole().getAll);
    if (mounted) {
      setState(() => _roles = roles);
    }
  }

  Future<void> _edit([ContactRole? role]) async {
    final controller = TextEditingController(text: role?.name);
    final form = GlobalKey<FormState>();
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(role == null ? 'Add role type' : 'Rename role'),
        scrollable: true,
        content: Form(
          key: form,
          child: HMBTextField(
            controller: controller,
            labelText: 'Role name',
            required: true,
          ),
        ),
        actions: [
          HMBSaveCancelButtons(
            cancelHint: 'Keep existing roles',
            saveHint: 'Save role type',
            onCancel: () => Navigator.pop(context),
            onSave: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
          ),
        ],
      ),
    );
    final value = await Navigator.of(context).push(route);
    await route.completed;
    // The dialog's exit animation has finished using the controller.
    controller.dispose();
    if (value == null || !mounted) {
      return;
    }
    await _run(() async {
      if (role == null) {
        await DaoContactRole().create(value);
      } else {
        await DaoContactRole().rename(role.id, value);
      }
    });
  }

  Future<void> _delete(ContactRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete role type?'),
        content: Text('Delete "${role.name}"? Roles in use cannot be deleted.'),
        actions: [
          HMBButtonSecondary(
            label: 'Cancel',
            hint: 'Keep role type',
            onPressed: () => Navigator.pop(context, false),
          ),
          HMBButtonPrimary(
            label: 'Delete',
            hint: 'Delete unused role type',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _run(() => DaoContactRole().delete(role.id));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await BlockingUI().runAndWait(action);
      await _load();
    } catch (error) {
      HMBToast.error(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => HMBFullPageChildScreen(
    title: 'Role types',
    child: DeferredBuilder(
      this,
      waitingBuilder: (_) => const SizedBox.shrink(),
      errorBuilder: (_, error) => const Text('Could not load roles.'),
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HMBButtonPrimary(
            label: 'Add role type',
            hint: 'Create a custom role',
            onPressed: _edit,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Standard roles are protected. Custom roles are '
              'labels and do not change billing or approval behaviour.',
            ),
          ),
          for (final role in _roles)
            ListTile(
              title: Text(role.name),
              subtitle: Text(role.builtin ? 'Standard role' : 'Custom role'),
              trailing: role.builtin
                  ? const Icon(Icons.lock_outline)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rename ${role.name}',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _edit(role),
                        ),
                        IconButton(
                          tooltip: 'Delete ${role.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(role),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    ),
  );
}
