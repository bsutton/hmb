/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/widgets.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../widgets.g.dart';
import 'hmb_droplist_multi.dart';

class HMBSelectMobileMulti extends StatefulWidget {
  final Job job;
  final void Function(List<String>) onChanged;

  /// One or more mobile numbers to preselect (whitespace tolerant).
  final List<String> initialMobiles;

  const HMBSelectMobileMulti({
    required this.job,
    required this.onChanged,
    this.initialMobiles = const [],
    super.key,
  });

  @override
  State<HMBSelectMobileMulti> createState() => _HMBSelectMobileMultiState();
}

class _HMBSelectMobileMultiState extends DeferredState<HMBSelectMobileMulti> {
  final preSelected = <ContactAndMobile>[];

  @override
  Future<void> asyncInitState() async {
    if (widget.initialMobiles.isEmpty) {
      return;
    }
    final all = await ContactAndMobile.fromJob(widget.job, null);

    String norm(String s) => s.replaceAll(' ', '').trim();
    final wanted = widget.initialMobiles
        .map(norm)
        .where((e) => e.isNotEmpty)
        .toSet();

    for (final item in all) {
      if (wanted.contains(norm(item.mobile))) {
        preSelected.add(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, _) => const Text('Could not load mobile recipients.'),
    builder: (_) =>
        HMBDroplistMultiSelect<ContactAndMobile>(
          initialItems: () async => preSelected,
          items: (filter) => ContactAndMobile.fromJob(widget.job, filter),
          format: (cm) => '${cm.contact.fullname}\n${cm.mobile}',
          onChanged: (selected) {
            preSelected
              ..clear()
              ..addAll(selected);
            widget.onChanged(selected.map((e) => e.mobile).toList());
          },
          title: 'To (Mobile)',
          backgroundColor: SurfaceElevation.e4.color,
          required: false,
        ).help('Select the mobile numbers.', '''
The selected mobile numbers will be added to the SMS "To" list.'''),
  );
}

@immutable
class ContactAndMobile {
  final Contact contact;
  final String mobile;

  const ContactAndMobile._(this.contact, this.mobile);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactAndMobile &&
          other.contact.id == contact.id &&
          other.mobile == mobile;

  @override
  int get hashCode => Object.hash(contact.id, mobile);

  /// Collect distinct mobile numbers for all contacts assigned to the job.
  static Future<List<ContactAndMobile>> fromJob(Job job, String? filter) async {
    final out = <ContactAndMobile>[];
    final seenMobiles = <String>{};
    final contacts = await DaoContact().getByJob(job.id);

    for (final c in contacts) {
      final mobile = c.mobileNumber.replaceAll(' ', '').trim();
      if (mobile.isNotEmpty && seenMobiles.add(mobile)) {
        out.add(ContactAndMobile._(c, mobile));
      }
    }

    if (Strings.isBlank(filter)) {
      return out;
    }
    final q = filter!.trim().toLowerCase();
    return out
        .where(
          (cm) =>
              cm.contact.fullname.toLowerCase().contains(q) ||
              cm.mobile.toLowerCase().contains(q),
        )
        .toList();
  }
}
