import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/widgets.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/job.dart';
import '../../../entity/todo.dart';
import '../../../util/flutter/notifications/local_notifs.dart';
import '../../widgets/select/select.g.dart';
import '../base_full_screen/base_full_screen.g.dart';
import 'edit_todo_card.dart';

class ToDoEditScreen extends StatefulWidget {
  final ToDo? toDo;

  /// We are being displayed from the job mini-dashboard
  /// so the parent is a Job and we don't let the user change it.
  final Job? preselectedJob;

  const ToDoEditScreen({required this.preselectedJob, super.key, this.toDo});

  @override
  State<ToDoEditScreen> createState() => _ToDoEditScreenState();
}

class _ToDoEditScreenState extends DeferredState<ToDoEditScreen>
    implements EntityState<ToDo> {
  @override
  ToDo? currentEntity;

  late ToDo _draft;

  ToDoParentType? _parentType;

  final selectedJob = SelectedJob();
  final selectedCustomer = SelectedCustomer();

  @override
  Future<void> asyncInitState() async {
    currentEntity = widget.toDo;

    // Seed a working draft from the entity (or a minimal new one)
    _draft =
        currentEntity ??
        ToDo.forInsert(
          title: '',
          parentType: widget.preselectedJob != null ? ToDoParentType.job : null,
          parentId: widget.preselectedJob?.id,
        );
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
      preSave: (todo) async => true,
      crossValidator: () async {
        // Validate based on the draft’s parentType/parentId
        switch (_draft.parentType) {
          case ToDoParentType.job:
            return _draft.parentId != null;
          case ToDoParentType.customer:
            return _draft.parentId != null;
          case null:
            return true;
        }
      },
      editor: (entity, {required isNew}) => ToDoEditorCard(
        todo: _draft,
        preselectedJob: widget.preselectedJob,
        onChanged: (updated) => setState(() => _draft = updated),
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
  Future<ToDo> forInsert() async => _draft;

  @override
  Future<ToDo> forUpdate(ToDo entity) async => _draft;

  int? getParentId() => switch (_parentType) {
    ToDoParentType.job => selectedJob.jobId,
    ToDoParentType.customer => selectedCustomer.customerId,
    _ => null,
  };
}
