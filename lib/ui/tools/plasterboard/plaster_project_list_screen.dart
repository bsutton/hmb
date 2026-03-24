/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.
*/

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/measurement_type.dart';
import '../../../util/dart/plaster_geometry.dart';
import '../../crud/base_full_screen/list_entity_screen.dart';
import '../../widgets/select/hmb_select_job.dart';
import '../../widgets/select/hmb_select_supplier.dart';
import '../../widgets/select/hmb_select_task.dart';
import 'plaster_project_screen.dart';

class PlasterProjectListScreen extends StatefulWidget {
  const PlasterProjectListScreen({super.key});

  @override
  State<PlasterProjectListScreen> createState() =>
      _PlasterProjectListScreenState();
}

class _PlasterProjectListScreenState extends State<PlasterProjectListScreen> {
  @override
  Widget build(BuildContext context) => EntityListScreen<PlasterProject>(
    entityNameSingular: 'Plasterboard Project',
    entityNamePlural: 'Plasterboard Projects',
    dao: DaoPlasterProject(),
    fetchList: (filter) => DaoPlasterProject().getByFilter(filter),
    listCardTitle: (project) => Text(project.name),
    onAdd: _addProject,
    onEdit: (project) => PlasterProjectScreen(project: project),
    cardHeight: 220,
    listCard: (project) => FutureBuilderEx(
      future: _loadSummary(project),
      builder: (context, summary) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job: ${summary!.job?.summary ?? 'Unknown'}'),
          Text('Task: ${summary.task?.name ?? 'Not set'}'),
          Text('Supplier: ${summary.supplier?.name ?? 'Not set'}'),
          Text('Rooms: ${summary.rooms.length}'),
          Text('Waste: ${project.wastePercent}%'),
        ],
      ),
    ),
  );

  Future<_ProjectSummary> _loadSummary(PlasterProject project) async {
    final job = await DaoJob().getById(project.jobId);
    final task = project.taskId == null
        ? null
        : await DaoTask().getById(project.taskId);
    final supplier = project.supplierId == null
        ? null
        : await DaoSupplier().getById(project.supplierId);
    final rooms = await DaoPlasterRoom().getByProject(project.id);
    return _ProjectSummary(job, task, supplier, rooms);
  }

  Future<PlasterProject?> _addProject() async {
    final draft = await showDialog<_ProjectDraft>(
      context: context,
      builder: (_) => const _CreateProjectDialog(),
    );
    if (draft == null) {
      return null;
    }
    final project = PlasterProject.forInsert(
      name: draft.name,
      jobId: draft.job.id,
      taskId: draft.task?.id,
      supplierId: draft.supplier?.id,
      wastePercent: 15,
    );
    final projectId = await DaoPlasterProject().insert(project);
    final saved = (await DaoPlasterProject().getById(projectId))!;
    final room = PlasterRoom.forInsert(
      projectId: projectId,
      name: 'Room 1',
      unitSystem: draft.unitSystem,
      ceilingHeight: PlasterGeometry.defaultCeilingHeight(draft.unitSystem),
    );
    final roomId = await DaoPlasterRoom().insert(room);
    final defaultLines = PlasterGeometry.defaultLines(
      roomId: roomId,
      unitSystem: draft.unitSystem,
    );
    for (final line in defaultLines) {
      await DaoPlasterRoomLine().insert(line);
    }
    for (final size in defaultMaterialSizes(projectId, draft.unitSystem)) {
      await DaoPlasterMaterialSize().insert(size);
    }
    return saved;
  }
}

class _ProjectSummary {
  final Job? job;
  final Task? task;
  final Supplier? supplier;
  final List<PlasterRoom> rooms;

  _ProjectSummary(this.job, this.task, this.supplier, this.rooms);
}

class _ProjectDraft {
  final String name;
  final Job job;
  final Task? task;
  final Supplier? supplier;
  final PreferredUnitSystem unitSystem;

  const _ProjectDraft({
    required this.name,
    required this.job,
    required this.task,
    required this.supplier,
    required this.unitSystem,
  });
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _selectedJob = SelectedJob();
  final _selectedTask = SelectedTask();
  final _selectedSupplier = SelectedSupplier();
  Job? _job;
  Task? _task;
  Supplier? _supplier;
  PreferredUnitSystem _unitSystem = PreferredUnitSystem.metric;
  String? _error;

  @override
  void initState() {
    super.initState();
    DaoSystem().get().then((system) {
      if (mounted) {
        setState(() {
          _unitSystem = system.preferredUnitSystem;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_job == null) {
      setState(() => _error = 'Select a job.');
      return;
    }
    final name = _nameController.text.trim().isEmpty
        ? '${_job!.summary} plasterboard'
        : _nameController.text.trim();
    Navigator.of(context).pop(
      _ProjectDraft(
        name: name,
        job: _job!,
        task: _task,
        supplier: _supplier,
        unitSystem: _unitSystem,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New Plasterboard Project'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Project Name'),
          ),
          HMBSelectJob(
            selectedJob: _selectedJob,
            required: true,
            onSelected: (job) {
              setState(() {
                _job = job;
                _task = null;
                _selectedTask.taskId = null;
              });
            },
          ),
          HMBSelectTask(
            selectedTask: _selectedTask,
            job: _job,
            onSelected: (task) => _task = task,
          ),
          HMBSelectSupplier(
            selectedSupplier: _selectedSupplier,
            onSelected: (supplier) => _supplier = supplier,
          ),
          DropdownButtonFormField<PreferredUnitSystem>(
            initialValue: _unitSystem,
            decoration: const InputDecoration(labelText: 'Units'),
            items: const [
              DropdownMenuItem(
                value: PreferredUnitSystem.metric,
                child: Text('Metric'),
              ),
              DropdownMenuItem(
                value: PreferredUnitSystem.imperial,
                child: Text('Imperial'),
              ),
            ],
            onChanged: (value) => setState(() {
              _unitSystem = value ?? PreferredUnitSystem.metric;
            }),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: const Text('Create')),
    ],
  );
}

List<PlasterMaterialSize> defaultMaterialSizes(
  int projectId,
  PreferredUnitSystem unitSystem,
) {
  if (unitSystem == PreferredUnitSystem.metric) {
    return [
      PlasterMaterialSize.forInsert(
        projectId: projectId,
        name: '1200 x 2400',
        unitSystem: unitSystem,
        width: 12000,
        height: 24000,
      ),
      PlasterMaterialSize.forInsert(
        projectId: projectId,
        name: '1200 x 2700',
        unitSystem: unitSystem,
        width: 12000,
        height: 27000,
      ),
      PlasterMaterialSize.forInsert(
        projectId: projectId,
        name: '1200 x 3000',
        unitSystem: unitSystem,
        width: 12000,
        height: 30000,
      ),
    ];
  }
  return [
    PlasterMaterialSize.forInsert(
      projectId: projectId,
      name: '4 x 8',
      unitSystem: unitSystem,
      width: 48000,
      height: 96000,
    ),
    PlasterMaterialSize.forInsert(
      projectId: projectId,
      name: '4 x 9',
      unitSystem: unitSystem,
      width: 48000,
      height: 108000,
    ),
    PlasterMaterialSize.forInsert(
      projectId: projectId,
      name: '4 x 10',
      unitSystem: unitSystem,
      width: 48000,
      height: 120000,
    ),
  ];
}
