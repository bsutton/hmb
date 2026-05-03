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

// lib/src/ui/receipt/receipt_list_screen.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/flutter_util.g.dart';
import '../../widgets/layout/layout.g.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/text/text.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/base_full_screen.g.dart';
import 'edit_receipt_screen.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  final _supplierFilter = SelectedSupplier();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Future<List<Receipt>> _fetchFilteredReceipts(String? filter) =>
      DaoReceipt().getByFilter(
        supplierFilter: filter,
        supplierId: _supplierFilter.selected,
        dateFrom: _startOfDay(_dateFrom),
        dateTo: _endOfDay(_dateTo),
      );

  DateTime? _startOfDay(DateTime? date) {
    if (date == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _endOfDay(DateTime? date) {
    if (date == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  Future<void> _selectDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onSelected,
    required VoidCallback onChange,
  }) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: current ?? DateTime.now(),
    );
    if (picked != null) {
      onSelected(picked);
      onChange();
    }
  }

  Widget _dateFilterTile({
    required String title,
    required DateTime? date,
    required ValueChanged<DateTime?> onSelected,
    required VoidCallback onChange,
  }) => ListTile(
    key: ValueKey('$title-$date'),
    title: Text(title),
    subtitle: Text(date == null ? 'Any date' : formatDate(date)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (date != null)
          IconButton(
            tooltip: 'Clear $title',
            onPressed: () {
              onSelected(null);
              onChange();
            },
            icon: const Icon(Icons.clear),
          ),
        const Icon(Icons.calendar_today),
      ],
    ),
    onTap: () =>
        _selectDate(current: date, onSelected: onSelected, onChange: onChange),
  );

  Widget _buildFilterSheet(void Function() onChange) => ListView(
    padding: const EdgeInsets.all(16),
    shrinkWrap: true,
    children: [
      HMBSelectSupplier(
        selectedSupplier: _supplierFilter,
        onSelected: (_) => onChange(),
      ).help('Filter by Supplier', 'Only show receipts for this supplier'),
      const SizedBox(height: 16),
      _dateFilterTile(
        title: 'Receipt Date From',
        date: _dateFrom,
        onSelected: (date) => setState(() => _dateFrom = date),
        onChange: onChange,
      ),
      _dateFilterTile(
        title: 'Receipt Date To',
        date: _dateTo,
        onSelected: (date) => setState(() => _dateTo = date),
        onChange: onChange,
      ),
    ],
  );

  void _clearFilters() {
    _supplierFilter.selected = null;
    _dateFrom = null;
    _dateTo = null;
  }

  @override
  Widget build(BuildContext context) => EntityListScreen<Receipt>(
    entityNameSingular: 'Receipt',
    entityNamePlural: 'Receipts',
    dao: DaoReceipt(),
    fetchList: _fetchFilteredReceipts,
    filterSheetBuilder: _buildFilterSheet,
    onFilterReset: _clearFilters,
    isFilterActive: () =>
        _supplierFilter.selected != null ||
        _dateFrom != null ||
        _dateTo != null,
    onEdit: (receipt) => ReceiptEditScreen(receipt: receipt),
    listCardTitle: _getTitle,
    cardHeight: 480,
    listCard: (r) => HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilderEx(
          future: DaoJob().getById(r.jobId),
          builder: (c, job) => HMBTextBody('Job: ${job?.summary ?? ''}'),
        ),
        FutureBuilderEx(
          future: DaoSupplier().getById(r.supplierId),
          builder: (c, sup) => HMBTextBody('Supplier: ${sup?.name ?? ''}'),
        ),
        HMBTextBody('Excl. Tax: ${r.totalExcludingTax}'),
        HMBTextBody('Tax: ${r.tax}'),
        HMBTextBody('Incl. Tax: ${r.totalIncludingTax}'),
        PhotoGallery.forReceipt(receipt: r),
      ],
    ),
  );

  Future<Widget> _getTitle(Receipt receipt) async {
    final supplier = await DaoSupplier().getById(receipt.supplierId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HMBTextHeadline3(
          ' ${formatDate(receipt.receiptDate, format: 'Y M d')}',
        ),
        HMBTextHeadline3(supplier!.name),
      ],
    );
  }
}
