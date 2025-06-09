// lib/src/ui/receipt/receipt_list_screen.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/util.g.dart';
import '../../widgets/media/photo_gallery.dart';
import '../../widgets/text/text.g.dart';
import '../base_full_screen/base_full_screen.g.dart';
import 'edit_receipt_screen.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  @override
  Widget build(BuildContext context) => EntityListScreen<Receipt>(
    pageTitle: 'Receipts',
    dao: DaoReceipt(),
    // ignore: discarded_futures
    fetchList: (_) => DaoReceipt().getByFilter(),
    onEdit: (receipt) => ReceiptEditScreen(receipt: receipt),
    title: _getTitle,
    cardHeight: 480,
    details: (r) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilderEx(
          // ignore: discarded_futures
          future: DaoJob().getById(r.jobId),
          builder: (c, job) => HMBTextBody('Job: ${job?.summary ?? ''}'),
        ),
        FutureBuilderEx(
          // ignore: discarded_futures
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
