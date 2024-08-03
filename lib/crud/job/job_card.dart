import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_status.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../invoicing/invoice_list_screen.dart';
import '../../quoting/quote_list_screen.dart';
import '../../util/format.dart';
import '../../widgets/hmb_email_text.dart';
import '../../widgets/hmb_phone_text.dart';
import '../../widgets/hmb_site_text.dart';
import '../../widgets/hmb_spacer.dart';
import '../../widgets/hmb_text.dart';
import '../../widgets/hmb_text_themes.dart';
import '../../widgets/photo_gallery.dart';
import '../../widgets/rich_editor.dart';

class JobCard extends StatelessWidget {
  const JobCard({required this.job, super.key});

  final Job job;

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoJobStatus().getById(job.jobStatusId),
        builder: (context, jobStatus) => FutureBuilderEx<Customer?>(
          // ignore: discarded_futures
          future: DaoCustomer().getById(job.customerId),
          builder: (context, customer) => Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBTextHeadline2(
                    customer?.name ?? 'Not Set',
                  ),
                  const SizedBox(height: 8),
                  _buildContactPoints(),
                  const SizedBox(height: 8),
                  HMBJobSiteText(label: '', job: job),
                  const SizedBox(height: 8),
                  HMBText(
                    'Status: ${jobStatus?.name ?? "Status Unknown"}',
                  ),
                  const SizedBox(height: 8),
                  HMBText(
                    'Scheduled: ${formatDate(job.startDate)}',
                  ),
                  const SizedBox(height: 8),
                  const HMBText('Description:', bold: true),
                  HMBText(
                    RichEditor.createParchment(job.description)
                        .toPlainText()
                        .split('\n')
                        .first,
                  ),
                  const SizedBox(height: 8),
                  PhotoGallery(job: job),
                  const SizedBox(height: 16),
                  buildStatistics(job),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildContactPoints() {
    final contactPoints = [
      HMBJobPhoneText(job: job),
      HMBJobEmailText(job: job)
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: (isMobile
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [...contactPoints],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [...contactPoints],
                  )));
      },
    );
  }

  FutureBuilderEx<JobStatistics> buildStatistics(Job job) => FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoJob().getJobStatistics(job),
        builder: (context, remainingTasks) {
          if (remainingTasks == null) {
            return const CircularProgressIndicator();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: isMobile
                    ? _buildMobileLayout(remainingTasks, context)
                    : _buildDesktopLayout(remainingTasks, context),
              );
            },
          );
        },
      );

  Widget _buildMobileLayout(JobStatistics stats, BuildContext context) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._buildStatistics(stats),
          const HMBSpacer(height: true),
          Row(
            children: [
              _buildQuoteButton(context),
              const HMBSpacer(width: true),
              _buildInvoiceButton(context),
            ],
          ),
        ],
      );

  Widget _buildDesktopLayout(JobStatistics stats, BuildContext context) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [..._buildStatistics(stats)]),
          const HMBSpacer(height: true),
          Row(children: [
            _buildQuoteButton(context),
            const HMBSpacer(width: true),
            _buildInvoiceButton(context),
          ]),
        ],
      );

  Widget _buildInvoiceButton(BuildContext context) => ElevatedButton(
        onPressed: () async => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => InvoiceListScreen(job: job),
        )),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text('Invoice'),
      );

  Widget _buildQuoteButton(BuildContext context) => ElevatedButton(
        onPressed: () async => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => FutureBuilderEx(
              future: DaoContact().getByJob(job.id),
              builder: (context, contacts) => QuoteListScreen(
                  job: job,
                  emailRecipients: contacts
                          ?.map((contact) => contact.emailAddress)
                          .toList() ??
                      [])),
        )),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text('Quote'),
      );

  List<Widget> _buildStatistics(JobStatistics remainingTasks) => [
        HMBText(
          'Tasks: ${remainingTasks.completedTasks}/${remainingTasks.totalTasks}',
          bold: true,
        ),
        const SizedBox(width: 16), //
        HMBText(
          'Est. Effort(hrs): ${remainingTasks.completedEffort.format('0.00')}/${remainingTasks.totalEffort.format('0.00')}',
          bold: true,
        ),
        const SizedBox(width: 16), //
        HMBText(
          'Earnings: ${remainingTasks.earnedCost}/${remainingTasks.totalCost}',
          bold: true,
        ),
        const SizedBox(width: 16), //
        HMBText(
            'Worked: ${remainingTasks.worked}/${remainingTasks.workedHours}hrs',
            bold: true)
      ];
}

class InvoiceScreenArguments {
  const InvoiceScreenArguments({required this.job});

  final Job job;
}
