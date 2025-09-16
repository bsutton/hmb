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

import '../dao.g.dart';
import 'notifiers.dart';

typedef DaoNotifierFn = void Function(DaoBase dao, int? entityId);
typedef NotifierFactory<T extends JuneState> = T Function();

/// ---- Public facade (kept for backward compatibility) ----
class DaoNotifications {
  DaoNotifications._();

  /// Notify app-wide listeners; pass [entityId] when available.
  static void notify(DaoBase dao, [int? entityId]) {
    JuneDaoNotifier.notify(dao, entityId);
  }
}

/// ---- Internal registry types ----
abstract class _Entry {
  JuneState Function() get create;
  void notify(int? entityId);
}

class _TypedEntry<T extends JuneState> implements _Entry {
  final T Function() _create;
  final void Function(T instance, int? entityId)? _onNotify;

  _TypedEntry(this._create, [this._onNotify]);

  @override
  JuneState Function() get create => _create;

  @override
  void notify(int? entityId) {
    final instance = June.getState<T>(_create);
    if (_onNotify != null) {
      _onNotify(instance, entityId);
    } else {
      instance.setState(); // default: refresh whole state
    }
  }
}

_TypedEntry<T> _reg<T extends JuneState>(
  T Function() create, {
  void Function(T instance, int? entityId)? onNotify,
}) => _TypedEntry<T>(create, onNotify);

/// ---- Core: single source of truth for creators + notifiers ----
class JuneDaoNotifier {
  static final Map<String, _Entry> _registry = {
    DaoCategory.tableName: _reg<CategoryNotifier>(CategoryNotifier.new),
    DaoCheckListItemCheckList.tableName: _reg<CheckListItemCheckListNotifier>(
      CheckListItemCheckListNotifier.new,
    ),
    DaoCheckListTask.tableName: _reg<CheckListTaskNotifier>(
      CheckListTaskNotifier.new,
    ),
    DaoContact.tableName: _reg<ContactNotifier>(ContactNotifier.new),
    DaoContactSupplier.tableName: _reg<ContactSupplierNotifier>(
      ContactSupplierNotifier.new,
    ),
    DaoCustomer.tableName: _reg<CustomerNotifier>(CustomerNotifier.new),
    DaoContactCustomer.tableName: _reg<ContactCustomerNotifier>(
      ContactCustomerNotifier.new,
    ),
    DaoInvoice.tableName: _reg<InvoiceNotifier>(InvoiceNotifier.new),
    DaoInvoiceLine.tableName: _reg<InvoiceLineNotifier>(
      InvoiceLineNotifier.new,
    ),
    DaoInvoiceLineGroup.tableName: _reg<InvoiceLineGroupNotifier>(
      InvoiceLineGroupNotifier.new,
    ),
    DaoJob.tableName: _reg<JobStateNotifier>(JobStateNotifier.new),
    DaoJobActivity.tableName: _reg<JobActivityNotifier>(
      JobActivityNotifier.new,
    ),
    DaoManufacturer.tableName: _reg<ManufacturerNotifier>(
      ManufacturerNotifier.new,
    ),
    DaoMilestone.tableName: _reg<MilestoneNotifier>(MilestoneNotifier.new),
    DaoMessageTemplate.tableName: _reg<MessageTemplateNotifier>(
      MessageTemplateNotifier.new,
    ),
    DaoPhoto.tableName: _reg<PhotoNotifier>(PhotoNotifier.new),
    DaoQuote.tableName: _reg<QuoteNotifier>(QuoteNotifier.new),
    DaoQuoteLine.tableName: _reg<QuoteLineNotifier>(QuoteLineNotifier.new),
    DaoQuoteLineGroup.tableName: _reg<QuoteLineGroupNotifier>(
      QuoteLineGroupNotifier.new,
    ),
    DaoReceipt.tableName: _reg<ReceiptNotifier>(ReceiptNotifier.new),
    DaoSite.tableName: _reg<SiteNotifier>(SiteNotifier.new),
    DaoSiteCustomer.tableName: _reg<SiteCustomerNotifier>(
      SiteCustomerNotifier.new,
    ),
    DaoSystem.tableName: _reg<SystemNotifier>(SystemNotifier.new),
    DaoSupplier.tableName: _reg<SupplierNotifier>(SupplierNotifier.new),
    DaoSiteSupplier.tableName: _reg<SiteSupplierNotifier>(
      SiteSupplierNotifier.new,
    ),
    DaoTask.tableName: _reg<TaskNotifier>(TaskNotifier.new),
    DaoTaskItem.tableName: _reg<TaskItemNotifier>(TaskItemNotifier.new),
    DaoTimeEntry.tableName: _reg<TimeEntryNotifier>(TimeEntryNotifier.new),
    DaoToDo.tableName: _reg<ToDoNotifier>(ToDoNotifier.new),
    DaoTool.tableName: _reg<ToolNotifier>(ToolNotifier.new),
    DaoVersion.tableName: _reg<VersionNotifier>(VersionNotifier.new),
    DaoWorkAssignment.tableName: _reg<WorkAssignmentNotifier>(
      WorkAssignmentNotifier.new,
    ),
    DaoWorkAssignmentTask.tableName: _reg<WorkAssignmentTaskNotifier>(
      WorkAssignmentTaskNotifier.new,
    ),

    // Example for future granular updates:
    // DaoTask.tableName: _reg<TaskNotifier>(
    //   TaskNotifier.new,
    //   onNotify: (notifier, id) => notifier.markDirty(id),
    // ),
  };

  /// Public notify entry point used by DaoNotifications
  static void notify(DaoBase dao, [int? entityId]) {
    final entry = _registry[dao.tablename];
    if (entry == null) {
      throw StateError(
        'Missing JuneDaoNotifier entry for table: ${dao.tablename}',
      );
    }
    entry.notify(entityId);
  }

  /// Return a *constructor* for the state (no June.getState here).
  static NotifierFactory<T> refresherForTable<T extends JuneState>(
    DaoBase baseDao,
  ) => refresherForTableName<T>(baseDao.tablename);

  /// Return a *constructor* for the state (no recursion).
  static NotifierFactory<T> refresherForTableName<T extends JuneState>(
    String tableName,
  ) {
    final entry = _registry[tableName];
    if (entry == null) {
      throw StateError('Missing JuneDaoNotifier entry for table: $tableName');
    }
    return () {
      final state = entry.create();
      if (state is! T) {
        throw StateError('''
Registered notifier for "$tableName" is ${state.runtimeType}, not $T.''');
      }
      return state;
    };
  }
}
