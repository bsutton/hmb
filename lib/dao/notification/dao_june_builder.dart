/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights
 Reserved.

 Note: This software is licensed under the GNU General Public
 License, with the following exceptions:
   • Permitted for internal use within your own business or
     organization only.
   • Any external distribution, resale, or incorporation into
     products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/widgets.dart';
import 'package:june/june.dart';

import '../../entity/entity.g.dart';
import '../dao.g.dart';
import 'dao_notifications.dart';
import 'notifiers.dart';

typedef HmbWidgetBuilder = Widget Function(BuildContext context);

// final JuneStateBuilder<T> builder;

/// Wraps JuneBuilder so you don't have to specify the notifier type.
/// It derives the notifier type from the provided DaoBase.
class DaoJuneBuilder<T extends Entity<T>> extends StatelessWidget {
  final DaoBase<T> dao;
  final JuneStateBuilder builder;
  final String? tag;
  final bool permanent;

  const DaoJuneBuilder({
    required this.dao,
    required this.builder,
    this.tag,
    this.permanent = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final table = dao.tablename;
    final factory = _builders[table];
    if (factory == null) {
      throw StateError(
        'No DaoJuneBuilder entry for table "$table". '
        'Did you add it to _builders?',
      );
    }
    return factory(builder);
  }

  /// tableName -> widget factory that returns the correctly typed JuneBuilder.
  /// Each entry captures the concrete notifier type, so inference never
  /// collapses to `JuneState`.
  static final Map<String, Widget Function(JuneStateBuilder builder)>
  _builders = {
    DaoCategory.tableName: (builder) => JuneBuilder<CategoryNotifier>(
      JuneDaoNotifier.refresherForTable<CategoryNotifier>(DaoCategory()),
      builder: builder,
    ),

    DaoCheckListItemCheckList.tableName: (builder) =>
        JuneBuilder<CheckListItemCheckListNotifier>(
          JuneDaoNotifier.refresherForTable<CheckListItemCheckListNotifier>(
            DaoCheckListItemCheckList(),
          ),

          builder: builder,
        ),

    DaoCheckListTask.tableName: (builder) => JuneBuilder<CheckListTaskNotifier>(
      JuneDaoNotifier.refresherForTable<CheckListTaskNotifier>(
        DaoCheckListTask(),
      ),

      builder: builder,
    ),

    DaoContact.tableName: (builder) => JuneBuilder<ContactNotifier>(
      JuneDaoNotifier.refresherForTable<ContactNotifier>(DaoContact()),

      builder: builder,
    ),

    DaoContactSupplier.tableName: (builder) =>
        JuneBuilder<ContactSupplierNotifier>(
          JuneDaoNotifier.refresherForTable<ContactSupplierNotifier>(
            DaoContactSupplier(),
          ),

          builder: builder,
        ),

    DaoCustomer.tableName: (builder) => JuneBuilder<CustomerNotifier>(
      JuneDaoNotifier.refresherForTable<CustomerNotifier>(DaoCustomer()),

      builder: builder,
    ),

    DaoContactCustomer.tableName: (builder) =>
        JuneBuilder<ContactCustomerNotifier>(
          JuneDaoNotifier.refresherForTable<ContactCustomerNotifier>(
            DaoContactCustomer(),
          ),

          builder: builder,
        ),

    DaoInvoice.tableName: (builder) => JuneBuilder<InvoiceNotifier>(
      JuneDaoNotifier.refresherForTable<InvoiceNotifier>(DaoInvoice()),

      builder: builder,
    ),

    DaoInvoiceLine.tableName: (builder) => JuneBuilder<InvoiceLineNotifier>(
      JuneDaoNotifier.refresherForTable<InvoiceLineNotifier>(DaoInvoiceLine()),

      builder: builder,
    ),

    DaoInvoiceLineGroup.tableName: (builder) =>
        JuneBuilder<InvoiceLineGroupNotifier>(
          JuneDaoNotifier.refresherForTable<InvoiceLineGroupNotifier>(
            DaoInvoiceLineGroup(),
          ),

          builder: builder,
        ),

    DaoJob.tableName: (builder) => JuneBuilder<JobStateNotifier>(
      JuneDaoNotifier.refresherForTable<JobStateNotifier>(DaoJob()),

      builder: builder,
    ),

    DaoJobActivity.tableName: (builder) => JuneBuilder<JobActivityNotifier>(
      JuneDaoNotifier.refresherForTable<JobActivityNotifier>(DaoJobActivity()),

      builder: builder,
    ),

    DaoManufacturer.tableName: (builder) => JuneBuilder<ManufacturerNotifier>(
      JuneDaoNotifier.refresherForTable<ManufacturerNotifier>(
        DaoManufacturer(),
      ),

      builder: builder,
    ),

    DaoMilestone.tableName: (builder) => JuneBuilder<MilestoneNotifier>(
      JuneDaoNotifier.refresherForTable<MilestoneNotifier>(DaoMilestone()),

      builder: builder,
    ),

    DaoMessageTemplate.tableName: (builder) =>
        JuneBuilder<MessageTemplateNotifier>(
          JuneDaoNotifier.refresherForTable<MessageTemplateNotifier>(
            DaoMessageTemplate(),
          ),

          builder: builder,
        ),

    DaoPhoto.tableName: (builder) => JuneBuilder<PhotoNotifier>(
      JuneDaoNotifier.refresherForTable<PhotoNotifier>(DaoPhoto()),

      builder: builder,
    ),

    DaoQuote.tableName: (builder) => JuneBuilder<QuoteNotifier>(
      JuneDaoNotifier.refresherForTable<QuoteNotifier>(DaoQuote()),

      builder: builder,
    ),

    DaoQuoteLine.tableName: (builder) => JuneBuilder<QuoteLineNotifier>(
      JuneDaoNotifier.refresherForTable<QuoteLineNotifier>(DaoQuoteLine()),

      builder: builder,
    ),

    DaoQuoteLineGroup.tableName: (builder) =>
        JuneBuilder<QuoteLineGroupNotifier>(
          JuneDaoNotifier.refresherForTable<QuoteLineGroupNotifier>(
            DaoQuoteLineGroup(),
          ),

          builder: builder,
        ),

    DaoReceipt.tableName: (builder) => JuneBuilder<ReceiptNotifier>(
      JuneDaoNotifier.refresherForTable<ReceiptNotifier>(DaoReceipt()),

      builder: builder,
    ),

    DaoSite.tableName: (builder) => JuneBuilder<SiteNotifier>(
      JuneDaoNotifier.refresherForTable<SiteNotifier>(DaoSite()),

      builder: builder,
    ),

    DaoSiteCustomer.tableName: (builder) => JuneBuilder<SiteCustomerNotifier>(
      JuneDaoNotifier.refresherForTable<SiteCustomerNotifier>(
        DaoSiteCustomer(),
      ),

      builder: builder,
    ),

    DaoSystem.tableName: (builder) => JuneBuilder<SystemNotifier>(
      JuneDaoNotifier.refresherForTable<SystemNotifier>(DaoSystem()),

      builder: builder,
    ),

    DaoSupplier.tableName: (builder) => JuneBuilder<SupplierNotifier>(
      JuneDaoNotifier.refresherForTable<SupplierNotifier>(DaoSupplier()),

      builder: builder,
    ),

    DaoSiteSupplier.tableName: (builder) => JuneBuilder<SiteSupplierNotifier>(
      JuneDaoNotifier.refresherForTable<SiteSupplierNotifier>(
        DaoSiteSupplier(),
      ),

      builder: builder,
    ),

    DaoTask.tableName: (builder) => JuneBuilder<TaskNotifier>(
      JuneDaoNotifier.refresherForTable<TaskNotifier>(DaoTask()),

      builder: builder,
    ),

    DaoTaskItem.tableName: (builder) => JuneBuilder<TaskItemNotifier>(
      JuneDaoNotifier.refresherForTable<TaskItemNotifier>(DaoTaskItem()),

      builder: builder,
    ),

    DaoTimeEntry.tableName: (builder) => JuneBuilder<TimeEntryNotifier>(
      JuneDaoNotifier.refresherForTable<TimeEntryNotifier>(DaoTimeEntry()),

      builder: builder,
    ),

    DaoToDo.tableName: (builder) => JuneBuilder<ToDoNotifier>(
      JuneDaoNotifier.refresherForTable<ToDoNotifier>(DaoToDo()),

      builder: builder,
    ),

    DaoTool.tableName: (builder) => JuneBuilder<ToolNotifier>(
      JuneDaoNotifier.refresherForTable<ToolNotifier>(DaoTool()),
      builder: builder,
    ),

    DaoVersion.tableName: (builder) => JuneBuilder<VersionNotifier>(
      JuneDaoNotifier.refresherForTable<VersionNotifier>(DaoVersion()),

      builder: builder,
    ),

    // Note: DaoWorkAssigment intentionally maps to WorkAssignmentNotifier.
    DaoWorkAssignment.tableName: (builder) =>
        JuneBuilder<WorkAssignmentNotifier>(
          JuneDaoNotifier.refresherForTable<WorkAssignmentNotifier>(
            DaoWorkAssignment(),
          ),

          builder: builder,
        ),

    DaoWorkAssignmentTask.tableName: (builder) =>
        JuneBuilder<WorkAssignmentTaskNotifier>(
          JuneDaoNotifier.refresherForTable<WorkAssignmentTaskNotifier>(
            DaoWorkAssignmentTask(),
          ),

          builder: builder,
        ),
  };
}
