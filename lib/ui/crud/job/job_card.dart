import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:strings/strings.dart';

import '../../../dao/dao_contact.dart';
import '../../../dao/dao_customer.dart';
import '../../../dao/dao_job.dart';
import '../../../dao/dao_job_status.dart';
import '../../../entity/customer.dart';
import '../../../entity/job.dart';
import '../../../util/format.dart';
import '../../invoicing/list_invoice_screen.dart';
import '../../quoting/list_quote_screen.dart';
import '../../widgets/layout/hmb_placeholder.dart';
import '../../widgets/layout/hmb_spacer.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/media/rich_editor.dart';
import '../../widgets/text/hmb_email_text.dart';
import '../../widgets/text/hmb_phone_text.dart';
import '../../widgets/text/hmb_site_text.dart';
import '../../widgets/text/hmb_text.dart';
import '../../widgets/text/hmb_text_themes.dart';
import 'rapid/rapid_quote_entry_screen.dart';

class JobCard extends StatefulWidget {
  const JobCard({required this.job, super.key});

  final Job job;

  @override
  // ignore: library_private_types_in_public_api
  _JobCardState createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  late Job job;

  @override
  void initState() {
    super.initState();
    job = widget.job;
  }

  Future<void> _refreshJob() async {
    final refreshedJob = await DaoJob().getById(job.id);
    setState(() {
      job = refreshedJob ?? job;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilderEx(
        waitingBuilder: (context) => const HMBPlaceHolder(height: 583),
        // ignore: discarded_futures
        future: DaoJobStatus().getById(job.jobStatusId),
        builder: (context, jobStatus) => FutureBuilderEx<Customer?>(
          waitingBuilder: (context) => const HMBPlaceHolder(height: 583),
          // ignore: discarded_futures
          future: DaoCustomer().getById(job.customerId),
          builder: (context, customer) => Card(
            margin: const EdgeInsets.all(8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () async {
                      if (context.mounted) {
                        await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (context) =>
                                    RapidQuoteEntryScreen(job: job)));
                      }
                    },
                    child: const Text('Rapid'),
                  ),
                  HMBTextHeadline2(
                    customer?.name ?? 'Not Set',
                  ),
                  const SizedBox(height: 8),
                  _buildContactPoints(),
                  const SizedBox(height: 8),
                  HMBJobSiteText(label: '', job: job),
                  const SizedBox(height: 8),
                  HMBText(
                    '''
# ${job.id} Status: ${jobStatus?.name ?? "Status Unknown"}''',
                  ),
                  const SizedBox(height: 8),
                  HMBText(
                    'Scheduled: ${formatDate(job.startDate)}',
                  ),
                  HMBText(
                    'Description:',
                    bold: true,
                  ),
                  HMBText(
                    RichEditor.createParchment(job.description)
                        .toPlainText()
                        .split('\n')
                        .first,
                  ),
                  const SizedBox(height: 8),
                  PhotoGallery.forJob(job: job),
                  const SizedBox(height: 16),
                  buildStatistics(job),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildContactPoints() => LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: (isMobile
                  ? Column(
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
                        Expanded(child: HMBJobEmailText(job: job))
                      ],
                    )));
        },
      );

  FutureBuilderEx<JobStatistics> buildStatistics(Job job) => FutureBuilderEx(
        waitingBuilder: (_) => const HMBPlaceHolder(height: 97),
        // ignore: discarded_futures
        future: DaoJob().getJobStatistics(job),
        builder: (context, remainingTasks) {
          if (remainingTasks == null) {
            return const CircularProgressIndicator();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 33,
            child: Row(children: [..._buildStatistics(stats)]),
          ),
          const HMBSpacer(height: true),
          Row(children: [
            _buildQuoteButton(context),
            const HMBSpacer(width: true),
            _buildInvoiceButton(context),
          ]),
        ],
      );

  Widget _buildInvoiceButton(BuildContext context) => ElevatedButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (context) => InvoiceListScreen(job: job),
          ));
          await _refreshJob(); // Refresh the job after returning
        },
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
                          ?.map((contact) => Strings.trim(contact.emailAddress))
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
            bold: true),
      ];
}

class InvoiceScreenArguments {
  const InvoiceScreenArguments({required this.job});

  final Job job;
}
