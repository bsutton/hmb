import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/ui/nav/dashboards/accounting/report_csv_export.dart';

void main() {
  test(
    'accounting report export filenames include entity and period context',
    () {
      expect(
        accountingReportExportFileName(
          reportName: 'job_profit',
          extension: 'pdf',
          entityName: 'UI Accounting Test Deck repair',
          entityId: 900003,
        ),
        'job_profit_ui_accounting_test_deck_repair_900003.pdf',
      );

      expect(
        accountingReportExportFileName(
          reportName: 'customer_statement',
          extension: '.csv',
          entityName: 'UI Accounting Test Beta',
          entityId: 42,
          startInclusive: DateTime(2026, 5),
          endInclusive: DateTime(2026, 5, 31),
        ),
        'customer_statement_ui_accounting_test_beta_42_'
        '2026-05-01_to_2026-05-31.csv',
      );
    },
  );
}
