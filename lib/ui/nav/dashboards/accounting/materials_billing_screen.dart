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

import 'package:material_ui/material_ui.dart';

import '../../../../dao/dao.g.dart';
import '../../../../entity/task_item.dart';
import '../../../../util/dart/format.dart';
import '../../../crud/check_list/edit_task_item_screen.dart';
import '../../../crud/check_list/list_task_item_screen.dart';
import '../../../widgets/icons/hmb_edit_icon.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/select/hmb_select_job.dart';
import '../../../widgets/widgets.g.dart';
import 'report_csv_export.dart';

enum MaterialBillingFilter {
  attention('Needs attention'),
  all('All'),
  unbilled('Not billed'),
  billed('Billed'),
  missingPrice('Missing price');

  const MaterialBillingFilter(this.label);

  final String label;
}

typedef MaterialBillingReportLoader = Future<MaterialBillingReport> Function();

class MaterialsBillingScreen extends StatefulWidget {
  final MaterialBillingReport report;
  final MaterialBillingReportLoader? reportLoader;

  const MaterialsBillingScreen({
    required this.report,
    this.reportLoader,
    super.key,
  });

  @override
  State<MaterialsBillingScreen> createState() => _MaterialsBillingScreenState();
}

class _MaterialsBillingScreenState extends State<MaterialsBillingScreen> {
  late MaterialBillingReport _report;
  final _selectedJob = SelectedJob();
  MaterialBillingFilter _filter = MaterialBillingFilter.attention;
  var _search = '';

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = _report.rows.where(_isVisible).toList();
    final visibleReport = MaterialBillingReport(rows: visibleRows);

    return Scaffold(
      appBar: AppBar(title: const Text('Materials Billing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(),
            const SizedBox(height: 12),
            _actions(context, visibleReport),
            const SizedBox(height: 12),
            HMBSelectJob(
              selectedJob: _selectedJob,
              onSelected: (_) => setState(() {}),
              showAdd: false,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 420,
              child: HMBSearch(
                label: 'Search customer, job, task or material',
                onSearch: (value) async {
                  setState(() => _search = value?.trim().toLowerCase() ?? '');
                },
              ),
            ),
            const SizedBox(height: 12),
            HMBSelectChips<MaterialBillingFilter>(
              label: 'Show',
              items: MaterialBillingFilter.values,
              value: _filter,
              format: (filter) => filter.label,
              onChanged: (filter) {
                if (filter != null) {
                  setState(() => _filter = filter);
                }
              },
            ),
            const SizedBox(height: 12),
            if (visibleRows.isEmpty)
              Surface(child: Text(_emptyMessage))
            else
              for (final row in visibleRows) _row(context, row),
          ],
        ),
      ),
    );
  }

  Widget _summary() => Surface(
    elevation: SurfaceElevation.e1,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        HMBChip(label: '${_report.rows.length} completed'),
        HMBChip(
          label: '${_report.unbilledCount} not billed',
          tone: _report.unbilledCount == 0
              ? HMBChipTone.accent
              : HMBChipTone.warning,
        ),
        HMBChip(
          label: '${_report.missingPriceCount} missing price',
          tone: _report.missingPriceCount == 0
              ? HMBChipTone.accent
              : HMBChipTone.danger,
        ),
      ],
    ),
  );

  Widget _actions(BuildContext context, MaterialBillingReport visibleReport) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          HMBButton.withIcon(
            label: 'Send CSV',
            hint: 'Email the visible materials billing rows as a CSV file',
            icon: const Icon(Icons.email),
            enabled: visibleReport.rows.isNotEmpty,
            onPressed: () async {
              await sendReportCsv(
                context: context,
                fileName: _exportFileName('csv'),
                title: 'Materials Billing',
                csv: AccountingReportCsvExporter().materialsBilling(
                  visibleReport,
                ),
              );
            },
          ),
          HMBButton.withIcon(
            label: 'View/Send PDF',
            hint: 'View and optionally email the visible billing rows as a PDF',
            icon: const Icon(Icons.picture_as_pdf),
            enabled: visibleReport.rows.isNotEmpty,
            onPressed: () async {
              await viewSendReportPdf(
                context: context,
                fileName: _exportFileName('pdf'),
                title: 'Materials Billing',
                rows: _pdfRows(visibleReport),
              );
            },
          ),
        ],
      );

  Widget _row(BuildContext context, MaterialBillingRow row) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Surface(
      elevation: SurfaceElevation.e1,
      child: HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.taskItem.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              HMBEditIcon(
                hint: 'Edit this task item',
                onPressed: () => _edit(row),
              ),
            ],
          ),
          Text('${row.customerName} · Job #${row.jobId}: ${row.jobSummary}'),
          Text('${row.taskName} · ${row.taskItem.itemType.label}'),
          Text('Updated ${formatDate(row.taskItem.modifiedDate)}'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (row.hasActualPrice)
                HMBChip(
                  label: 'Actual: ${row.actualCost}',
                  tone: HMBChipTone.accent,
                )
              else
                const HMBChip(
                  label: 'Actual price missing',
                  tone: HMBChipTone.danger,
                  icon: Icons.error_outline,
                ),
              if (row.taskItem.billed)
                HMBChip(
                  label: row.invoiceDisplay.isEmpty
                      ? 'Billed'
                      : 'Billed on ${row.invoiceDisplay}',
                  tone: HMBChipTone.accent,
                  icon: Icons.receipt_long,
                )
              else
                const HMBChip(
                  label: 'Not billed',
                  tone: HMBChipTone.warning,
                  icon: Icons.pending_actions,
                ),
              HMBChip(label: 'Charge: ${row.charge}'),
            ],
          ),
        ],
      ),
    ),
  );

  bool _isVisible(MaterialBillingRow row) {
    if (_selectedJob.jobId != null && _selectedJob.jobId != row.jobId) {
      return false;
    }

    final statusMatches = switch (_filter) {
      MaterialBillingFilter.attention =>
        !row.taskItem.billed || !row.hasActualPrice,
      MaterialBillingFilter.all => true,
      MaterialBillingFilter.unbilled => !row.taskItem.billed,
      MaterialBillingFilter.billed => row.taskItem.billed,
      MaterialBillingFilter.missingPrice => !row.hasActualPrice,
    };
    if (!statusMatches || _search.isEmpty) {
      return statusMatches;
    }

    return [
      row.customerName,
      row.jobId.toString(),
      row.jobSummary,
      row.taskName,
      row.taskItem.description,
      row.taskItem.itemType.label,
      row.invoiceDisplay,
    ].any((value) => value.toLowerCase().contains(_search));
  }

  String get _emptyMessage => _filter == MaterialBillingFilter.attention
      ? 'All completed materials have a price and have been billed.'
      : 'No completed materials match this filter.';

  Future<void> _edit(MaterialBillingRow row) async {
    final task = await DaoTask().getById(row.taskItem.taskId);
    final taskItem = await DaoTaskItem().getById(row.taskItem.id);
    if (!mounted) {
      return;
    }
    if (task == null || taskItem == null) {
      HMBToast.error('This task item no longer exists.');
      await _reload();
      return;
    }

    final taskAndRate = await TaskAndRate.fromTask(task);
    if (!mounted) {
      return;
    }
    final updated = await Navigator.of(context).push<TaskItem>(
      MaterialPageRoute(
        builder: (_) => TaskItemEditScreen(
          parent: task,
          taskItem: taskItem,
          billingType: taskAndRate.billingType,
          hourlyRate: taskAndRate.rate,
        ),
      ),
    );
    if (updated != null && mounted) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    final loader =
        widget.reportLoader ?? AccountingReportService().materialsBilling;
    final report = await BlockingUI().runAndWait(
      loader,
      label: 'Refreshing materials billing',
    );
    if (mounted) {
      setState(() => _report = report);
    }
  }

  List<List<String>> _pdfRows(MaterialBillingReport report) => [
    ['Customer', 'Job', 'Task', 'Item', 'Cost', 'Charge', 'Status', 'Invoice'],
    for (final row in report.rows)
      [
        row.customerName,
        '#${row.jobId} ${row.jobSummary}',
        row.taskName,
        row.taskItem.description,
        row.actualCost?.toString() ?? 'Missing',
        row.charge.toString(),
        if (row.taskItem.billed) 'Billed' else 'Not billed',
        row.invoiceDisplay,
      ],
  ];

  String _exportFileName(String extension) => accountingReportExportFileName(
    reportName: 'materials_billing',
    extension: extension,
    asAt: DateTime.now(),
  );
}
