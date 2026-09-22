import 'package:hmb/ui/widgets/fields/hmb_integer_field.dart';
import 'package:hmb/ui/widgets/fields/hmb_money_editing_controller.dart';
import 'package:hmb/ui/widgets/fields/hmb_money_field.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_area.dart';
import 'package:hmb/ui/widgets/fields/hmb_text_field.dart';
import 'package:hmb/ui/widgets/hmb_button.dart';
import 'package:hmb/ui/widgets/hmb_chip.dart';
import 'package:hmb/ui/widgets/hmb_menu_chip.dart';
import 'package:hmb/ui/widgets/hmb_select_chips.dart';
import 'package:hmb/ui/widgets/hmb_switch.dart';
import 'package:hmb/ui/widgets/hmb_toggle.dart';
import 'package:hmb/ui/widgets/icons/hmb_delete_icon.dart';
import 'package:hmb/ui/widgets/icons/hmb_edit_icon.dart';
import 'package:hmb/ui/widgets/icons/hmb_icon_button.dart';
import 'package:hmb/ui/widgets/layout/labeled_container.dart';
import 'package:hmb/ui/widgets/layout/surface.dart';
import 'package:hmb/ui/widgets/select/hmb_droplist.dart';
import 'package:hmb/ui/widgets/text/hmb_text_themes.dart';
import 'package:hmb/util/flutter/hmb_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Run with `flutter run -t tool/style_preview.dart` to inspect shared controls.
void main() =>
    runApp(MaterialApp(theme: HMBTheme.dark, home: const HMBStylePreview()));

/// A database-free reference for the HMB style, using fictional content.
class HMBStylePreview extends StatefulWidget {
  const HMBStylePreview({super.key});

  @override
  State<HMBStylePreview> createState() => _HMBStylePreviewState();
}

class _HMBStylePreviewState extends State<HMBStylePreview> {
  final _contact = TextEditingController(text: 'Jane Smith');
  final _quantity = TextEditingController(text: '4');
  final _rate = HMBMoneyEditingController()..text = '85.00';
  final _notes = TextEditingController(text: 'Repair and repaint the hallway.');
  final _reference = TextEditingController(text: 'JOB-1042');
  final _required = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _priority = 'Normal';
  String? _role = 'Site Contact';
  var _status = 'Scheduled';
  var _reminders = true;
  var _notify = false;
  var _lastAction = 'Try an action below.';
  var _validation = 'Leave the required field empty to preview an error.';

  @override
  void dispose() {
    for (final controller in [
      _contact,
      _quantity,
      _rate,
      _notes,
      _reference,
      _required,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('HMB style')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Apartment repairs',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Parkside Owners Corporation',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HMBChip(
                  label: 'Scheduled',
                  tone: HMBChipTone.accent,
                  icon: Icons.calendar_today_outlined,
                ),
                HMBChip(label: 'Automatic'),
                HMBChip(label: 'Overdue', tone: HMBChipTone.danger),
              ],
            ),
            const SizedBox(height: 16),
            SurfaceCardWithActions(
              title: 'Parties',
              summary: true,
              padding: const EdgeInsets.all(HMBTheme.sectionPadding),
              actions: [
                HMBButtonSecondary(
                  label: 'Manage',
                  hint: 'Manage parties',
                  quiet: true,
                  onPressed: () {},
                ),
              ],
              body: Column(
                children: [
                  _party(context, 'Jane Smith', 'Primary Contact'),
                  const Divider(),
                  _party(context, 'Alex Brown', 'Site Contact'),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '2 contacts · 2 roles',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCardWithActions(
              title: 'Billing',
              summary: true,
              padding: const EdgeInsets.all(HMBTheme.sectionPadding),
              actions: [
                HMBButtonSecondary(
                  label: 'Change',
                  hint: 'Change billing',
                  quiet: true,
                  onPressed: () {},
                ),
              ],
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bill to customer',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Text('Parkside Owners Corporation'),
                  const Divider(),
                  Text(
                    'Send invoices to',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Text('Jane Smith'),
                  const SizedBox(height: 8),
                  HMBButtonSecondary(
                    label: 'Change billing contact',
                    hint: 'Choose a billing contact',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SurfaceCardWithActions(
              title: 'Controls',
              summary: true,
              padding: const EdgeInsets.all(HMBTheme.sectionPadding),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HMBTextField(
                    fieldKey: const ValueKey('preview-contact'),
                    controller: _contact,
                    labelText: 'Contact',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HMBButtonPrimary(
                        label: 'Add party',
                        hint: 'Add party',
                        onPressed: () => _showDialog(context),
                      ),
                      HMBButtonSecondary(
                        label: 'Cancel',
                        hint: 'Cancel',
                        quiet: true,
                        onPressed: () {},
                      ),
                      HMBButton(
                        label: 'Disabled',
                        hint: 'Unavailable',
                        enabled: false,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _fields(),
            const SizedBox(height: 12),
            _selections(),
            const SizedBox(height: 12),
            _actions(),
            const SizedBox(height: 12),
            _typography(),
            const SizedBox(height: 12),
            _surfaces(),
          ],
        ),
      ),
    ),
  );

  Widget _section(String title, String description, List<Widget> children) =>
      SurfaceCardWithActions(
        title: title,
        summary: true,
        padding: const EdgeInsets.all(HMBTheme.sectionPadding),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _fields() => _section(
    'Fields & validation',
    'HMBIntegerField · HMBMoneyField · HMBTextArea · HMBTextField',
    [
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HMBIntegerField(
              controller: _quantity,
              labelText: 'Quantity',
              positive: true,
            ),
            const SizedBox(height: 12),
            HMBMoneyField(
              controller: _rate,
              labelText: 'Hourly rate',
              fieldName: 'rate',
            ),
            const SizedBox(height: 12),
            HMBTextArea(controller: _notes, labelText: 'Notes', maxLines: 3),
            const SizedBox(height: 12),
            HMBTextField(
              controller: _reference,
              labelText: 'Reference (disabled)',
              enabled: false,
            ),
            const SizedBox(height: 12),
            HMBTextField(
              controller: _required,
              labelText: 'Summary',
              fieldKey: const ValueKey('preview-required'),
              required: true,
            ),
            const SizedBox(height: 12),
            HMBButtonSecondary(
              label: 'Validate fields',
              hint: 'Show validation',
              onPressed: () {
                final valid = _formKey.currentState!.validate();
                setState(
                  () => _validation = valid
                      ? 'All fields are valid.'
                      : 'Check the highlighted fields.',
                );
              },
            ),
            Text(_validation, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ],
  );

  Widget _selections() => _section(
    'Selections & switches',
    'HMBDroplist · HMBSelectChips · HMBMenuChip · HMBSwitch · HMBToggle',
    [
      HMBDroplist<String>(
        title: 'Role',
        fieldKey: const ValueKey('preview-role'),
        initialValue: _role,
        selectedItem: () async => _role,
        items: (filter) async =>
            ['Site Contact', 'Billing Contact', 'Authoriser']
                .where(
                  (role) =>
                      role.toLowerCase().contains((filter ?? '').toLowerCase()),
                )
                .toList(),
        format: (role) => role,
        onChanged: (role) => setState(() => _role = role),
      ),
      const SizedBox(height: 12),
      HMBSelectChips<String>(
        label: 'Priority',
        items: const ['Low', 'Normal', 'High'],
        value: _priority,
        format: (value) => value,
        onChanged: (value) => setState(() => _priority = value),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: HMBMenuChip<String>(
          label: _status,
          values: const ['Scheduled', 'In progress', 'Complete'],
          format: (value) => value,
          tone: HMBChipTone.accent,
          tooltip: 'Change sample status',
          onSelected: (value) => setState(() => _status = value),
        ),
      ),
      HMBSwitch(
        labelText: 'Reminders',
        initialValue: _reminders,
        onChanged: (value) => setState(() => _reminders = value),
      ),
      HMBToggle(
        label: 'Notify',
        hint: 'Toggle notifications',
        initialValue: _notify,
        onToggled: (value) => setState(() => _notify = value),
      ),
      Text(
        'Priority: $_priority · Notifications: ${_notify ? 'on' : 'off'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  void _recordAction(String label) =>
      setState(() => _lastAction = '$label tapped');

  Widget _actions() => _section(
    'Buttons & icons',
    'HMBButton variants · HMBIconButton sizes · HMBEditIcon · HMBDeleteIcon',
    [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          HMBButton.withIcon(
            label: 'Save',
            icon: const Icon(Icons.save_outlined),
            hint: 'Preview save',
            onPressed: () => _recordAction('Save'),
          ),
          HMBButton.small(
            label: 'Small',
            hint: 'Compact button',
            onPressed: () => _recordAction('Small'),
          ),
          HMBButton.smallWithIcon(
            label: 'Add',
            icon: const Icon(Icons.add),
            hint: 'Compact icon button',
            onPressed: () => _recordAction('Add'),
          ),
          const HMBButtonSecondary(
            label: 'Unavailable',
            hint: 'Disabled secondary',
            onPressed: null,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final size in HMBIconButtonSize.values)
            HMBIconButton(
              size: size,
              icon: const Icon(Icons.check),
              hint: '${size.name} icon action',
              onPressed: () async => _recordAction(size.name),
            ),
          HMBEditIcon(
            hint: 'Preview edit',
            onPressed: () async => _recordAction('Edit'),
          ),
          HMBDeleteIcon(
            hint: 'Preview delete',
            onPressed: () async => _recordAction('Delete'),
          ),
          const HMBIconButton(
            icon: Icon(Icons.lock_outline),
            hint: 'Disabled icon',
            enabled: false,
            onPressed: null,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(_lastAction, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          HMBChip(label: 'Neutral'),
          HMBChip(label: 'Accent', tone: HMBChipTone.accent),
          HMBChip(label: 'Warning', tone: HMBChipTone.warning),
          HMBChip(label: 'Danger', tone: HMBChipTone.danger),
        ],
      ),
    ],
  );

  Widget _typography() => _section(
    'Typography',
    'Existing HMB text widgets with the shared style.',
    [
      const HMBPageTitle('Page title'),
      const HMBCardTitle('Card title'),
      const HMBCardHeading('Card heading'),
      HMBTextSectionHeading('Section'),
      HMBTextBody('Body text wraps naturally for longer job descriptions.'),
      HMBTextBodyBold('Important detail'),
      HMBTextLabel('Field label'),
      HMBUTextAncillary('Ancillary information'),
      const HMBTextNotice('A short notice'),
      const HMBTextError('Example error'),
      const SizedBox(height: 8),
      const HMBTextLine('Single line with ellipsis for longer content'),
    ],
  );

  Widget _surfaces() => _section(
    'Surfaces & containers',
    'Surface elevations · SurfaceCard · LabeledContainer',
    [
      for (final elevation in [
        SurfaceElevation.e1,
        SurfaceElevation.e4,
        SurfaceElevation.e8,
      ]) ...[
        Surface(
          elevation: elevation,
          rounded: true,
          padding: const EdgeInsets.all(12),
          child: Text('Surface ${elevation.name}'),
        ),
        const SizedBox(height: 8),
      ],
      const SurfaceCard(
        title: 'Simple card',
        body: Text('Card without actions.'),
      ),
      const SizedBox(height: 8),
      const LabeledContainer(
        labelText: 'Group label',
        backgroundColor: HMBColors.surface4dp,
        child: Text('Related content in a labelled container.'),
      ),
    ],
  );

  Widget _party(BuildContext context, String name, String role) => SizedBox(
    width: double.infinity,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 16,
      runSpacing: 4,
      children: [
        Text(name),
        Text(role, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Future<void> _showDialog(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add party'),
      content: const Text('Assign a contact and role to this job.'),
      actions: [
        HMBButtonSecondary(
          label: 'Cancel',
          hint: 'Close dialog',
          quiet: true,
          onPressed: () => Navigator.pop(context),
        ),
        HMBButtonPrimary(
          label: 'Add',
          hint: 'Confirm',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
