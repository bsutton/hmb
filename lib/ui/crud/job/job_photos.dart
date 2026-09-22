import 'package:deferred_state/deferred_state.dart';
import 'package:material_ui/material_ui.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/widgets.g.dart';
import '../task/photo_crud.dart';

/// Reuses task photo capture, comments and deletion for job-owned photos.
class JobPhotos extends StatefulWidget {
  final Job job;
  const JobPhotos({required this.job, super.key});

  @override
  State<JobPhotos> createState() => _JobPhotosState();
}

class _JobPhotosState extends DeferredState<JobPhotos> {
  late final _controller = PhotoController<Job>(
    parent: widget.job,
    parentType: ParentType.job,
  );
  final _taskControllers = <PhotoController<Task>>[];

  @override
  Future<void> asyncInitState() async {
    await BlockingUI().runAndWait(() async {
      final photos = await DaoPhoto.getJobGallery(widget.job.id);
      final taskIds = photos
          .where((meta) => meta.photo.parentType == ParentType.task)
          .map((meta) => meta.photo.parentId)
          .toSet();
      for (final id in taskIds) {
        final task = await DaoTask().getById(id);
        if (task != null) {
          _taskControllers.add(
            PhotoController<Task>(parent: task, parentType: ParentType.task),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _taskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    waitingBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (_, error) => const Text('Could not load job photos.'),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Job photos'),
        PhotoCrud<Job>(
          parentName: 'Job',
          parentType: ParentType.job,
          controller: _controller,
        ),
        for (final controller in _taskControllers) ...[
          Text(controller.parent!.name),
          PhotoCrud<Task>(
            parentName: 'Task',
            parentType: ParentType.task,
            controller: controller,
          ),
        ],
      ],
    ),
  );
}
