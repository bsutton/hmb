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

/// Global notification hook. Set this from the app (Flutter) layer.
/// In CLI tools, leave it unset (no-op).
class DaoNotifications {
  /// Optional notifier installed by the environment (Flutter adapter).
  static DaoNotifierFn? notifier;

  DaoNotifications._();

  /// Utility for DAOs to emit a change.
  static void notify(DaoBase dao, int? entityId) {
    final fn = notifier;
    if (fn != null) {
      fn(dao, entityId);
    }
  }
}

typedef JuneStateCreator = JuneState Function();

/// Install this once during Flutter app startup to wire DAOs to June.
class JuneDaoNotifier {
  /// Map of tableName -> June refresher constructor
  static final Map<String, JuneStateCreator> _registry = {
    DaoCategory.tableName: CategoryNotifier.new,
    DaoCheckListItemCheckList.tableName: CheckListItemCheckListNotifier.new,
    DaoCheckListTask.tableName: CheckListTaskNotifier.new,
    DaoContact.tableName: ContactNotifier.new,
    DaoContactSupplier.tableName: ContactSupplierNotifier.new,
    DaoCustomer.tableName: CustomerNotifier.new,
    DaoContactCustomer.tableName: ContactCustomerNotifier.new,
    DaoInvoice.tableName: InvoiceNotifier.new,
    DaoInvoiceLine.tableName: InvoiceLineNotifier.new,
    DaoInvoiceLineGroup.tableName: InvoiceLineGroupNotifier.new,
    DaoJob.tableName: JobStateNotifier.new,
    DaoJobActivity.tableName: JobActivityNotifier.new,
    DaoManufacturer.tableName: ManufacturerNotifier.new,
    DaoMilestone.tableName: MilestoneNotifier.new,
    DaoMessageTemplate.tableName: MessageTemplateNotifier.new,
    DaoPhoto.tableName: PhotoNotifier.new,
    DaoQuote.tableName: QuoteNotifier.new,
    DaoQuoteLine.tableName: QuoteLineNotifier.new,
    DaoQuoteLineGroup.tableName: QuoteLineGroupNotifier.new,
    DaoReceipt.tableName: ReceiptNotifier.new,
    DaoSite.tableName: SiteNotifier.new,
    DaoSiteCustomer.tableName: SiteCustomerNotifier.new,
    DaoSystem.tableName: SystemNotifier.new,
    DaoSupplier.tableName: SupplierNotifier.new,
    DaoSiteSupplier.tableName: SiteSupplierNotifier.new,
    DaoTask.tableName: TaskNotifier.new,
    DaoTaskItem.tableName: TaskItemNotifier.new,
    DaoTimeEntry.tableName: TimeEntryNotifier.new,
    DaoToDo.tableName: ToDoNotifier.new,
    DaoTool.tableName: ToolNotifier.new,
    DaoVersion.tableName: VersionNotifier.new,
    DaoWorkAssigment.tableName: WorkAssignmentTaskNotifier.new,
    DaoWorkAssignmentTask.tableName: WorkAssignmentTaskNotifier.new,
  };

  static JuneState Function() refresherFor(DaoBase baseDao) =>
      refresherForTable(baseDao.tablename);

  static JuneState Function() refresherForTable(String tableName) {
    final refresher = _registry[tableName];

    if (refresher == null) {
      throw StateError('''
Missing entry form the JuneDaoNotifier registry for $tableName''');
    }

    return refresher;
  }

  /// Function that matches DaoBase's notifier signature.
  void notify(DaoBase dao, int? entityId) {
    final table = dao.tablename;
    final creator = _registry[table];
    if (creator == null) {
      throw StateError(
        'Missing entry form the JuneDaoNotifier registry for $table',
      );
    }

    // Notify June for the specific table (optionally passing the entityId)
    June.getState(creator).setState([if (entityId != null) entityId]);
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
