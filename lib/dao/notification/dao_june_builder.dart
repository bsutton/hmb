import 'package:flutter/widgets.dart';
import 'package:june/june.dart';

import '../dao.g.dart';
import 'notifiers.dart';

typedef NotifierFactory<T extends JuneState> = T Function();

///
/// Creates a JuneBuilder for a specific Dao class that will
/// be rebuilt every time an update occurs agains that Dao
/// .i.e a rebuild occurs on insert, update and delete as
/// well as usage of the DaoBase.direct method.
///
/// For each Dao class we need to add a registry entry below.
/// To use the builder add the following to your widget tree.
///
/// ```dart
/// child: DaoJuneBuilder.builder(
///              DaoToDo(),
///              builder: (context) => Text('Some content')
/// ```
///
class DaoJuneBuilder {
  static final Map<String, _TypedEntry> _registry = {
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
    DaoBookingRequest.tableName: _reg<BookingRequestNotifier>(
      BookingRequestNotifier.new,
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
  };

  static void notify(DaoBase dao, [int? entityId]) {
    final entry = _registry[dao.tablename];
    if (entry == null) {
      throw StateError('Missing registry entry for table: ${dao.tablename}');
    }
    entry.notify(entityId);
  }

  /// Accepts a plain `WidgetBuilder` (BuildContext -> Widget).
  /// Internally adapts it to the `JuneStateBuilder<T>`
  /// that JuneBuilder expects.
  static Widget builder(
    DaoBase dao, {
    required WidgetBuilder builder,
    String? tag,
    bool global = true,
    bool autoRemove = true,
    bool assignId = false,
    Object? id,
  }) {
    final entry = _registry[dao.tablename];
    if (entry == null) {
      throw StateError('Missing registry entry for table: ${dao.tablename}');
    }
    return entry.buildFromContext(
      builder,
      tag: tag,
      global: global,
      autoRemove: autoRemove,
      assignId: assignId,
      id: id,
    );
  }
}

class _TypedEntry<T extends JuneState> {
  final T Function() _create;
  final void Function(T instance, int? entityId)? _onNotify;

  _TypedEntry(this._create, [this._onNotify]);

  void notify(int? entityId) {
    final instance = June.getState<T>(_create);
    if (_onNotify != null) {
      _onNotify(instance, entityId);
    } else {
      instance.setState();
    }
  }

  /// Wrap the caller's `WidgetBuilder` inside a `Builder`,
  /// and ignore the `T` parameter JuneBuilder will give us.
  Widget buildFromContext(
    WidgetBuilder simpleBuilder, {
    String? tag,
    bool global = true,
    bool autoRemove = true,
    bool assignId = false,
    Object? id,
  }) => JuneBuilder<T>(
    _create,
    tag: tag,
    global: global,
    autoRemove: autoRemove,
    assignId: assignId,
    id: id,
    builder: (_) => Builder(builder: (ctx) => simpleBuilder(ctx)),
  );
}

_TypedEntry<T> _reg<T extends JuneState>(
  T Function() create, {
  void Function(T instance, int? entityId)? onNotify,
}) => _TypedEntry<T>(create, onNotify);
