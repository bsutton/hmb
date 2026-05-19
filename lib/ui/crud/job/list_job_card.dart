/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../dao/dao.g.dart';
import '../../../dao/notification/dao_june_builder.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/format.dart';
import '../../../util/dart/local_date.dart';
import '../../dialog/source_context.dart';
import '../../widgets/icons/hmb_edit_icon.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/text/hmb_text.dart';
import '../../widgets/text/hmb_text_block.dart';
import '../../widgets/text/hmb_text_themes.dart';
import '../../widgets/widgets.g.dart';
import '../customer/edit_customer_screen.dart';
import 'mini_job_dashboard.dart';

class ListJobCard extends StatefulWidget {
  final Job job;

  const ListJobCard({required this.job, super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ListJobCardState createState() => _ListJobCardState();
}

class _ListJobCardState extends DeferredState<ListJobCard> {
  late Job job;
  late final JobActivity? nextActivity;
  late Customer? customer;
  late Contact? primaryContact;

  @override
  Future<void> asyncInitState() async {
    job = widget.job;
    nextActivity = await DaoJobActivity().getNextActivityByJob(job.id);
    await _loadCustomerDetails();
  }

  Future<void> _loadCustomerDetails() async {
    customer = await DaoCustomer().getById(job.customerId);
    final contact = await DaoContact().getPrimaryForJob(job.id);

    /// we don't want to repeat the name if they are the same.
    /// We ignore case and spaces when comparing.
    if (customer?.name.toLowerCase().trim().replaceAll(' ', '') ==
        contact?.fullname.toLowerCase().trim().replaceAll(' ', '')) {
      primaryContact = null;
    } else {
      primaryContact = contact;
    }
  }

  @override
  void didUpdateWidget(ListJobCard old) {
    if (job != widget.job) {
      job = widget.job;
    }
    super.didUpdateWidget(old);
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => Surface(
      padding: EdgeInsets.zero,
      elevation: SurfaceElevation.e6,
      child: _buildDetails(job.status),
    ),
  );

  Widget _buildDetails(JobStatus? jobStatus) => DaoJuneBuilder.builder(
    DaoJob(),
    builder: (jobRefresher) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        _buildCustomerHeading(),
        if (primaryContact != null)
          HMBTextHeadline2(primaryContact?.fullname ?? 'Not Set'),
        _buildContactPoints(),
        HMBJobSiteText(
          label: '',
          job: job,
          onMapClicked: () async {
            await DaoJob().markActive(job.id);
            await DaoActivity().recordNavigatedToJob(jobId: job.id);
          },
        ),
        HMBRow(
          children: [
            HMBText('Job #${job.id}', bold: true),
            HMBText('Status: ${jobStatus?.displayName ?? 'Status Unknown'}'),
          ],
        ),
        _buildNextActivity(),
        const HMBText('Description:', bold: true),
        HMBTextBlock(job.description, maxLines: 1),
        MiniJobDashboard(job: job),
      ],
    ),
  );

  Widget _buildCustomerHeading() => HMBRow(
    children: [
      Expanded(child: HMBCardHeading(customer?.name ?? 'Not Set')),
      IconButton(
        icon: const Icon(Icons.contact_phone),
        tooltip: 'Contact job parties',
        onPressed: _showJobContacts,
      ),
      if (customer != null)
        HMBEditIcon(
          onPressed: _editCustomer,
          hint: 'Edit customer contacts and sites',
        ),
    ],
  );

  Future<void> _showJobContacts() async {
    final contacts = await _loadJobPartyContacts();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Job Contacts'),
        content: SizedBox(
          width: 520,
          child: contacts.isEmpty
              ? const Text('No contacts are linked to this job.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, index) =>
                      _JobPartyContactTile(contact: contacts[index]),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<List<_JobPartyContact>> _loadJobPartyContacts() async {
    final site = await DaoSite().getById(job.siteId);
    final customer = await DaoCustomer().getById(job.customerId);
    final referrer = await DaoCustomer().getById(job.referrerCustomerId);
    final rows = <_JobPartyContact>[];
    final seen = <String>{};

    Future<void> add({
      required String role,
      required int? contactId,
      Customer? partyCustomer,
    }) async {
      if (contactId == null) {
        return;
      }
      final contact = await DaoContact().getById(contactId);
      if (contact == null) {
        return;
      }
      final key = '$role:${contact.id}';
      if (!seen.add(key)) {
        return;
      }
      rows.add(
        _JobPartyContact(
          role: role,
          contact: contact,
          sourceContext: SourceContext(
            job: job,
            contact: contact,
            customer: partyCustomer ?? customer,
            site: site,
          ),
        ),
      );
    }

    await add(
      role: 'Primary',
      contactId: job.contactId,
      partyCustomer: customer,
    );
    await add(
      role: 'Tenant',
      contactId: job.tenantContactId,
      partyCustomer: customer,
    );
    await add(
      role: 'Billing',
      contactId: job.billingContactId,
      partyCustomer: job.billingParty == BillingParty.referrer
          ? referrer
          : customer,
    );
    await add(
      role: 'Referrer',
      contactId: job.referrerContactId,
      partyCustomer: referrer,
    );

    return rows;
  }

  Future<void> _editCustomer() async {
    final selectedCustomer = customer;
    if (selectedCustomer == null) {
      HMBToast.error('No customer is linked to this job.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => CustomerEditScreen(customer: selectedCustomer),
      ),
    );
    await _loadCustomerDetails();
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildNextActivity() {
    String activity;
    Color textColor;
    if (nextActivity == null) {
      activity = 'Not Scheduled';
      textColor = Colors.red;
    } else if (nextActivity!.start.toLocalDate() == LocalDate.today()) {
      activity = formatTime(nextActivity!.start);
      textColor = Colors.orange;
    } else {
      activity = formatDateTime(nextActivity!.start);
      textColor = Colors.white;
    }
    return HMBText('Next Activity: $activity', color: textColor);
  }

  Widget _buildContactPoints() => LayoutBuilder(
    builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      return isMobile
          ? HMBColumn(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HMBJobPhoneText(job: job),
                HMBJobEmailText(job: job),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HMBJobPhoneText(job: job),
                Expanded(child: HMBJobEmailText(job: job)),
              ],
            );
    },
  );
}

class _JobPartyContact {
  final String role;
  final Contact contact;
  final SourceContext sourceContext;

  const _JobPartyContact({
    required this.role,
    required this.contact,
    required this.sourceContext,
  });
}

class _JobPartyContactTile extends StatelessWidget {
  final _JobPartyContact contact;

  const _JobPartyContactTile({required this.contact});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${contact.role}: ${contact.contact.fullname}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      HMBPhoneText(
        phoneNo: contact.contact.bestPhone,
        sourceContext: contact.sourceContext,
      ),
      HMBEmailText(email: contact.contact.emailAddress),
    ],
  );
}
