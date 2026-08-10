/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../dao/dao_mailing.dart';
import '../../../dao/dao_mailing_recipient.dart';
import '../../../dao/dao_system.dart';
import '../../../entity/mailing.dart';
import '../../../util/flutter/app_title.dart';
import '../../widgets/blocking_ui.dart';
import '../../widgets/hmb_toast.dart';
import '../../widgets/icons/hmb_add_button.dart';
import '../../widgets/icons/hmb_delete_icon.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/text/hmb_text_themes.dart';
import 'label_layout.dart';
import 'mailing_edit_screen.dart';

class MailingListScreen extends StatefulWidget {
  const MailingListScreen({super.key});

  @override
  State<MailingListScreen> createState() => _MailingListScreenState();
}

class _MailingListScreenState extends State<MailingListScreen> {
  final _mailingDao = DaoMailing();
  List<Mailing> _mailings = [];
  var _creating = false;

  @override
  void initState() {
    super.initState();
    setAppTitle('Mailings');
    unawaited(_load());
  }

  Future<void> _load() async {
    final mailings = await _mailingDao.getByFilter(null);
    if (mounted) {
      setState(() => _mailings = mailings);
    }
  }

  Future<void> _createMailing() async {
    final name = await _askForMailingName();
    if (name == null || name.trim().isEmpty || _creating) {
      return;
    }
    setState(() => _creating = true);
    Mailing? mailing;
    try {
      await BlockingUI().runAndWait(() async {
        final system = await DaoSystem().get();
        final layout = LabelLayout.forUnitSystem(
          system.preferredUnitSystem,
        ).first;
        final created = Mailing.forInsert(
          name: name.trim(),
          labelLayoutId: layout.id,
          routeOrigin: system.address,
        );
        await _mailingDao.insert(created);
        await DaoMailingRecipient().populateForMailing(created.id);
        mailing = created;
      }, label: 'Creating Mailing');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
    await _load();
    if (mounted && mailing != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_open(mailing!));
        }
      });
    }
  }

  Future<String?> _askForMailingName() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Mailing'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mailing name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final name = value.text.trim();
                return TextButton(
                  onPressed: name.isEmpty
                      ? null
                      : () => Navigator.pop(context, name),
                  child: child!,
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _open(Mailing mailing) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MailingEditScreen(mailingId: mailing.id),
      ),
    );
    await _load();
  }

  Future<void> _delete(Mailing mailing) async {
    await _mailingDao.delete(mailing.id);
    HMBToast.info('Mailing deleted');
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mailings'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: HMBButtonAdd(
            enabled: !_creating,
            hint: 'Create a new mailing',
            onAdd: _createMailing,
          ),
        ),
      ],
    ),
    body: _mailings.isEmpty
        ? const Center(child: Text('No mailings yet.'))
        : ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _mailings.length,
            itemBuilder: (context, index) {
              final mailing = _mailings[index];
              return Card(
                child: ListTile(
                  title: HMBCardHeading(mailing.name),
                  subtitle: Text(mailing.status.display),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      HMBEditIcon(
                        hint: 'Edit mailing',
                        onPressed: () => _open(mailing),
                      ),
                      HMBDeleteIcon(
                        hint: 'Delete mailing',
                        onPressed: () => _delete(mailing),
                      ),
                    ],
                  ),
                  onTap: () => unawaited(_open(mailing)),
                ),
              );
            },
          ),
  );
}
