import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/widgets.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/todo.dart';
import '../../../util/dart/date_time_ex.dart';
import '../../../util/dart/local_time.dart';
import '../../../util/flutter/notifications/local_notifs.dart';
import '../../widgets/fields/fields.g.dart';
import '../../widgets/select/select.g.dart';
import '../../widgets/widgets.g.dart';
import '../base_full_screen/base_full_screen.g.dart';

class ToDoEditScreen extends StatefulWidget {
  final ToDo? toDo;

  const ToDoEditScreen({super.key, this.toDo});

  @override
  State<ToDoEditScreen> createState() => _ToDoEditScreenState();
}

class _ToDoEditScreenState extends DeferredState<ToDoEditScreen>
    implements EntityState<ToDo> {
  @override
  ToDo? currentEntity;

  late TextEditingController _title;
  late TextEditingController _note;
  ToDoPriority _priority = ToDoPriority.none;
  ToDoStatus _status = ToDoStatus.open;

  ToDoParentType? _parentType;

  final selectedJob = SelectedJob();
  final selectedCustomer = SelectedCustomer();

  DateTime? _dueDate;
  DateTime? _remindAt;
  DateTime? _completedDate;

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.toDo;
    _title = TextEditingController(text: currentEntity?.title);
    _note = TextEditingController(text: currentEntity?.note ?? '');
    _priority = currentEntity?.priority ?? ToDoPriority.none;
    _status = currentEntity?.status ?? ToDoStatus.open;
    _parentType = currentEntity?.parentType;
    await _getParent(currentEntity?.parentType, currentEntity?.parentId);
    _dueDate = currentEntity?.dueDate;
    _remindAt = currentEntity?.remindAt;
    _completedDate = currentEntity?.completedDate;
  }

  Future<void> _getParent(ToDoParentType? parentType, int? parentId) async {
    switch (parentType) {
      case ToDoParentType.job:
        {
          final job = await DaoJob().getById(parentId);
          selectedJob.jobId = job?.id;
        }
      case ToDoParentType.customer:
        {
          final customer = await DaoCustomer().getById(parentId);
          selectedCustomer.customerId = customer?.id;
        }
      case null:
    }
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => EntityEditScreen<ToDo>(
      entityName: 'To-Do',
      dao: DaoToDo(),
      entityState: this,
      // Use this to schedule/cancel notifications after save.
      preSave: (todo) async => true,
      crossValidator: () async => switch (_parentType) {
        ToDoParentType.job => selectedJob.jobId != null,
        ToDoParentType.customer => selectedCustomer.customerId != null,
        _ => selectedCustomer.customerId == null && selectedJob.jobId == null,
      },

      editor: (entity, {required isNew}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HMBTextField(controller: _title, labelText: 'Title', required: true),
          HMBTextArea(controller: _note, labelText: 'Notes'),

          // Context picker (None / Job / Customer)
          HMBSelectChips<ToDoParentType?>(
            label: 'Context',
            value: _parentType,
            items: const [null, ToDoParentType.job, ToDoParentType.customer],
            format: (v) => v == null ? 'None' : v.name,
            onChanged: (v) => setState(() {
              _parentType = v;
              selectedCustomer.customerId = null;
              selectedJob.jobId = null;
            }),
          ),
          if (_parentType == ToDoParentType.job)
            HMBSelectJob(
              selectedJob: selectedJob,
              required: true,
              onSelected: (job) async {
                await _getParent(ToDoParentType.job, job?.id);
                setState(() {});
              },
            ),
          if (_parentType == ToDoParentType.customer)
            HMBSelectCustomer(
              selectedCustomer: selectedCustomer,
              required: true,
              onSelected: (c) async {
                await _getParent(ToDoParentType.customer, c?.id);
                setState(() {});
              },
            ),
          HMBSelectChips<ToDoPriority>(
            label: 'Priority',
            value: _priority,
            items: ToDoPriority.values,
            format: (v) => v.name,
            onChanged: (v) => setState(() => _priority = v!),
          ),
          HMBDateTimeField(
            label: 'Due By',
            mode: HMBDateTimeFieldMode.dateAndTime,
            initialDateTime:
                _dueDate ??
                DateTime.now()
                    .add(const Duration(days: 3))
                    .withTime(const LocalTime(hour: 9, minute: 0)),
            onChanged: (d) => _dueDate = d,
          ),
          HMBDateTimeField(
            label: 'Reminder',
            mode: HMBDateTimeFieldMode.dateAndTime,
            initialDateTime:
                _remindAt ??
                DateTime.now()
                    .add(const Duration(days: 2))
                    .withTime(const LocalTime(hour: 9, minute: 0)),
            onChanged: (d) => _remindAt = d,
          ),
          HMBSelectChips<ToDoStatus>(
            label: 'Status',
            value: _status,
            items: ToDoStatus.values,
            format: (v) => v.name,
            onChanged: (v) {
              setState(() {
                _status = v!;
                _completedDate = _status == ToDoStatus.done
                    ? DateTime.now()
                    : null;
              });
            },
          ),
        ],
      ),
    ),
  );

  @override
  Future<void> postSave(ToDo entity) async {
    if (entity.status == ToDoStatus.done || entity.remindAt == null) {
      await LocalNotifs().cancelForToDo(entity.id);
      return;
    }

    if (entity.remindAt != null) {
      await LocalNotifs().scheduleForToDo(entity);
    }
  }

  @override
  Future<ToDo> forInsert() async => ToDo.forInsert(
    title: _title.text,
    note: _note.text.trim().isEmpty ? null : _note.text,
    priority: _priority,
    status: _status,
    dueDate: _dueDate,
    remindAt: _remindAt,
    parentType: _parentType,
    parentId: getParentId(),
  );

  @override
  Future<ToDo> forUpdate(ToDo entity) async => ToDo.forUpdate(
    entity: entity,
    title: _title.text,
    note: _note.text.trim().isEmpty ? null : _note.text,
    priority: _priority,
    status: _status,
    dueDate: _dueDate,
    remindAt: _remindAt,
    parentType: _parentType,
    parentId: getParentId(),
    completedDate: _completedDate,
  );

  int? getParentId() => switch (_parentType) {
    ToDoParentType.job => selectedJob.jobId,
    ToDoParentType.customer => selectedCustomer.customerId,
    _ => null,
  };
}
