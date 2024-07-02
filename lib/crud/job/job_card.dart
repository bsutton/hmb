import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../dao/dao_contact.dart';
import '../../dao/dao_customer.dart';
import '../../dao/dao_job.dart';
import '../../dao/dao_job_status.dart';
import '../../dao/dao_site.dart';
import '../../entity/customer.dart';
import '../../entity/job.dart';
import '../../invoicing/invoice_list_screen.dart';
import '../../util/format.dart';
import '../../widgets/hmb_email_text.dart';
import '../../widgets/hmb_phone_text.dart';
import '../../widgets/hmb_site_text.dart';
import '../../widgets/hmb_text.dart';
import '../../widgets/hmb_text_themes.dart';
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
            builder: (context, customer) => FutureBuilderEx(
              // ignore: discarded_futures
              future: DaoSite().getByJob(job),
              builder: (context, site) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HMBTextHeadline3(customer?.name ?? 'Not Set'),
                  FutureBuilderEx(
                    // ignore: discarded_futures
                    future: DaoContact().getById(job.contactId),
                    builder: (context, contact) => Column(
                      children: [
                        HMBPhoneText(
                            phoneNo:
                                contact?.mobileNumber ?? contact?.landLine),
                        HMBEmailText(email: contact?.emailAddress)
                      ],
                    ),
                  ),
                  HMBSiteText(label: '', site: site),
                  HMBText('Status: ${jobStatus?.name ?? "Status Unknown"} '),
                  HMBText('Scheduled: ${formatDate(job.startDate)}'),
                  HMBText(
                    '''Description: ${RichEditor.createParchment(job.description).toPlainText().split('\n').first}''',
                  ),
                  buildStatistics(job)
                ],
              ),
            ),
          ));

  FutureBuilderEx<JobStatistics> buildStatistics(Job job) => FutureBuilderEx(
        // ignore: discarded_futures
        future: DaoJob().getJobStatistics(job),
        builder: (context, remainingTasks) {
          if (remainingTasks == null) {
            return const CircularProgressIndicator();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                // Mobile layout
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._buildStatistics(remainingTasks),
                    _buildInvoiceButton(context)
                  ],
                );
              } else {
                // Desktop layout
                return Row(
                  children: [
                    ..._buildStatistics(remainingTasks),
                    _buildInvoiceButton(context)
                  ],
                );
              }
            },
          );
        },
      );

  Widget _buildInvoiceButton(BuildContext context) => ElevatedButton(
        onPressed: () async => Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => InvoiceListScreen(job: job),
        )),
        child: const Text('Invoice'),
        // onPressed: () async => Navigator.of(context).pushNamed(
        //   XeroAuthScreen.routeName,
        //   arguments: InvoiceScreenArguments(job: job),
        // ),
      );

  List<Widget> _buildStatistics(JobStatistics remainingTasks) => [
        HMBText(
          'Completed: ${remainingTasks.completedTasks}/${remainingTasks.totalTasks}',
        ),
        const SizedBox(width: 16), //
        HMBText(
          'Effort(hrs): ${remainingTasks.completedEffort.format('0.00')}/${remainingTasks.totalEffort.format('0.00')}',
        ),
        const SizedBox(width: 16), //
        HMBText(
          'Earnings: ${remainingTasks.earnedCost}/${remainingTasks.totalCost}',
        ),
        const SizedBox(width: 16), //
        HMBText(
          ' Worked: ${remainingTasks.worked}/${remainingTasks.workedHours}hrs',
        )
      ];
}

class InvoiceScreenArguments {
  const InvoiceScreenArguments({required this.job});

  final Job job;
}
