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

import 'package:june/june.dart';

import 'dao.g.dart';

typedef DaoNotifierFn = void Function(DaoBase dao, int? entityId);

class DaoNotifications {
  DaoNotifications._();

  /// Utility for DAOs to emit a change; pass an entityId if you have it.
  static void notify(DaoBase dao, [int? entityId]) {
    JuneDaoNotifier.notify(dao, entityId);
  }
}

typedef JuneStateCreator<T extends JuneState> = T Function();
typedef NotifierFactory<T extends JuneState> = T Function();

/// Install this once during Flutter app startup to wire DAOs to June.
class JuneDaoNotifier {
  /// Map of tableName -> notify thunk.
  /// We accept an optional entityId for future per-entity optimizations.
  static final Map<String, void Function(int? entityId)> _notifiers = {
    DaoCategory.tableName: (_) =>
        June.getState<CategoryNotifier>(CategoryNotifier.new).setState(),

    DaoCheckListItemCheckList.tableName: (_) =>
        June.getState<CheckListItemCheckListNotifier>(
          CheckListItemCheckListNotifier.new,
        ).setState(),

    DaoCheckListTask.tableName: (_) => June.getState<CheckListTaskNotifier>(
      CheckListTaskNotifier.new,
    ).setState(),

    DaoContact.tableName: (_) =>
        June.getState<ContactNotifier>(ContactNotifier.new).setState(),

    DaoContactSupplier.tableName: (_) => June.getState<ContactSupplierNotifier>(
      ContactSupplierNotifier.new,
    ).setState(),

    DaoCustomer.tableName: (_) =>
        June.getState<CustomerNotifier>(CustomerNotifier.new).setState(),

    DaoContactCustomer.tableName: (_) => June.getState<ContactCustomerNotifier>(
      ContactCustomerNotifier.new,
    ).setState(),

    DaoInvoice.tableName: (_) =>
        June.getState<InvoiceNotifier>(InvoiceNotifier.new).setState(),

    DaoInvoiceLine.tableName: (_) =>
        June.getState<InvoiceLineNotifier>(InvoiceLineNotifier.new).setState(),

    DaoInvoiceLineGroup.tableName: (_) =>
        June.getState<InvoiceLineGroupNotifier>(
          InvoiceLineGroupNotifier.new,
        ).setState(),

    DaoJob.tableName: (_) =>
        June.getState<JobStateNotifier>(JobStateNotifier.new).setState(),

    DaoJobActivity.tableName: (_) =>
        June.getState<JobActivityNotifier>(JobActivityNotifier.new).setState(),

    DaoManufacturer.tableName: (_) => June.getState<ManufacturerNotifier>(
      ManufacturerNotifier.new,
    ).setState(),

    DaoMilestone.tableName: (_) =>
        June.getState<MilestoneNotifier>(MilestoneNotifier.new).setState(),

    DaoMessageTemplate.tableName: (_) => June.getState<MessageTemplateNotifier>(
      MessageTemplateNotifier.new,
    ).setState(),

    DaoPhoto.tableName: (_) =>
        June.getState<PhotoNotifier>(PhotoNotifier.new).setState(),

    DaoQuote.tableName: (_) =>
        June.getState<QuoteNotifier>(QuoteNotifier.new).setState(),

    DaoQuoteLine.tableName: (_) =>
        June.getState<QuoteLineNotifier>(QuoteLineNotifier.new).setState(),

    DaoQuoteLineGroup.tableName: (_) => June.getState<QuoteLineGroupNotifier>(
      QuoteLineGroupNotifier.new,
    ).setState(),

    DaoReceipt.tableName: (_) =>
        June.getState<ReceiptNotifier>(ReceiptNotifier.new).setState(),

    DaoSite.tableName: (_) =>
        June.getState<SiteNotifier>(SiteNotifier.new).setState(),

    DaoSiteCustomer.tableName: (_) => June.getState<SiteCustomerNotifier>(
      SiteCustomerNotifier.new,
    ).setState(),

    DaoSystem.tableName: (_) =>
        June.getState<SystemNotifier>(SystemNotifier.new).setState(),

    DaoSupplier.tableName: (_) =>
        June.getState<SupplierNotifier>(SupplierNotifier.new).setState(),

    DaoSiteSupplier.tableName: (_) => June.getState<SiteSupplierNotifier>(
      SiteSupplierNotifier.new,
    ).setState(),

    DaoTask.tableName: (_) =>
        June.getState<TaskNotifier>(TaskNotifier.new).setState(),

    DaoTaskItem.tableName: (_) =>
        June.getState<TaskItemNotifier>(TaskItemNotifier.new).setState(),

    DaoTimeEntry.tableName: (_) =>
        June.getState<TimeEntryNotifier>(TimeEntryNotifier.new).setState(),

    DaoToDo.tableName: (_) =>
        June.getState<ToDoNotifier>(ToDoNotifier.new).setState(),

    DaoTool.tableName: (_) =>
        June.getState<ToolNotifier>(ToolNotifier.new).setState(),

    DaoVersion.tableName: (_) =>
        June.getState<VersionNotifier>(VersionNotifier.new).setState(),

    DaoWorkAssignment.tableName: (_) => June.getState<WorkAssignmentNotifier>(
      WorkAssignmentNotifier.new,
    ).setState(),

    DaoWorkAssignmentTask.tableName: (_) =>
        June.getState<WorkAssignmentTaskNotifier>(
          WorkAssignmentTaskNotifier.new,
        ).setState(),
  };

  /// Notify listeners for this DAO/table. `entityId` is optional.
  static void notify(DaoBase dao, [int? entityId]) {
    final table = dao.tablename;
    final thunk = _notifiers[table];
    if (thunk == null) {
      throw StateError('Missing JuneDaoNotifier entry for table: $table');
    }
    thunk(entityId);
  }

  // === refreshers stay the same ===

  static NotifierFactory<T> refresherForTable<T extends JuneState>(
    DaoBase baseDao,
  ) => refresherForTableName<T>(baseDao.tablename);

  static NotifierFactory<T> refresherForTableName<T extends JuneState>(
    String tableName,
  ) {
    final thunk = _notifiers[tableName];
    if (thunk == null) {
      throw StateError('Missing JuneDaoNotifier entry for table: $tableName');
    }

    return () => June.getState<T>(() {
      throw StateError(
        'No June state of type $T is registered for "$tableName". '
        'Ensure the corresponding notifier is created at app startup '
        'or call DaoNotifications.notify(dao) once to initialise it.',
      );
    });
  }
}

class CategoryNotifier extends JuneState {
  CategoryNotifier();
}

class CheckListItemCheckListNotifier extends JuneState {
  CheckListItemCheckListNotifier();
}

class CheckListTaskNotifier extends JuneState {
  CheckListTaskNotifier();
}

class ContactNotifier extends JuneState {
  ContactNotifier();
}

class ContactSupplierNotifier extends JuneState {
  ContactSupplierNotifier();
}

class CustomerNotifier extends JuneState {
  CustomerNotifier();
}

class ContactCustomerNotifier extends JuneState {
  ContactCustomerNotifier();
}

class InvoiceNotifier extends JuneState {
  InvoiceNotifier();
}

class InvoiceLineNotifier extends JuneState {
  InvoiceLineNotifier();
}

class InvoiceLineGroupNotifier extends JuneState {
  InvoiceLineGroupNotifier();
}

class JobStateNotifier extends JuneState {
  JobStateNotifier();
}

class JobActivityNotifier extends JuneState {
  JobActivityNotifier();
}

class ManufacturerNotifier extends JuneState {
  ManufacturerNotifier();
}

class MessageTemplateNotifier extends JuneState {
  MessageTemplateNotifier();
}

class MilestoneNotifier extends JuneState {
  MilestoneNotifier();
}

class PhotoNotifier extends JuneState {
  PhotoNotifier();
}

class QuoteNotifier extends JuneState {
  QuoteNotifier();
}

class QuoteLineNotifier extends JuneState {
  QuoteLineNotifier();
}

class QuoteLineGroupNotifier extends JuneState {
  QuoteLineGroupNotifier();
}

class ReceiptNotifier extends JuneState {
  ReceiptNotifier();
}

class SiteNotifier extends JuneState {
  SiteNotifier();
}

class SiteCustomerNotifier extends JuneState {
  SiteCustomerNotifier();
}

class SiteSupplierNotifier extends JuneState {
  SiteSupplierNotifier();
}

class SupplierNotifier extends JuneState {
  SupplierNotifier();
}

class SystemNotifier extends JuneState {
  SystemNotifier();
}

class TaskNotifier extends JuneState {
  TaskNotifier();
}

class TaskItemNotifier extends JuneState {
  TaskItemNotifier();
}

class TimeEntryNotifier extends JuneState {
  TimeEntryNotifier();
}

class ToDoNotifier extends JuneState {
  ToDoNotifier();
}

class ToolNotifier extends JuneState {
  ToolNotifier();
}

class VersionNotifier extends JuneState {
  VersionNotifier();
}

class WorkAssignmentNotifier extends JuneState {
  WorkAssignmentNotifier();
}

class WorkAssignmentTaskNotifier extends JuneState {
  WorkAssignmentTaskNotifier();
}
