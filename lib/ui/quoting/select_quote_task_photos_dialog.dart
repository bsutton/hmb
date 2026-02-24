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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_photo.dart';
import '../../dao/dao_quote_task_photo.dart';
import '../../entity/quote_line_group.dart';
import '../../entity/quote_task_photo.dart';
import '../../util/dart/photo_meta.dart';
import '../widgets/media/photo_carousel.dart';
import '../widgets/widgets.g.dart';
import 'quote_details.dart';

class SelectQuoteTaskPhotosDialog extends StatefulWidget {
  final int quoteId;

  const SelectQuoteTaskPhotosDialog({required this.quoteId, super.key});

  static Future<void> show({
    required BuildContext context,
    required int quoteId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => SelectQuoteTaskPhotosDialog(quoteId: quoteId),
    );
  }

  @override
  State<SelectQuoteTaskPhotosDialog> createState() =>
      _SelectQuoteTaskPhotosDialogState();
}

class _SelectQuoteTaskPhotosDialogState
    extends State<SelectQuoteTaskPhotosDialog> {
  final _groups = <_TaskPhotoGroupData>[];
  final _selectedByTask = <int, List<int>>{};
  final _commentControllers = <String, TextEditingController>{};
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final details = await QuoteDetails.fromQuoteId(
        widget.quoteId,
        excludeHidden: true,
      );
      final existing = await DaoQuoteTaskPhoto().getByQuote(widget.quoteId);
      final existingByTask = <int, List<QuoteTaskPhoto>>{};
      for (final selection in existing) {
        existingByTask.putIfAbsent(selection.taskId, () => []).add(selection);
      }

      for (final wrapped in details.groups) {
        final group = wrapped.group;
        final taskId = group.taskId;
        if (taskId == null) {
          continue;
        }

        final photos = await DaoPhoto.getByTask(taskId);
        await PhotoMeta.resolveAll(photos);

        _groups.add(_TaskPhotoGroupData(group: group, photos: photos));

        final byPhotoId = <int, PhotoMeta>{};
        for (final meta in photos) {
          byPhotoId[meta.photo.id] = meta;
        }

        final orderedSelections = (existingByTask[taskId] ?? [])
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        final selected = <int>[];
        for (final selection in orderedSelections) {
          final meta = byPhotoId[selection.photoId];
          if (meta == null) {
            continue;
          }
          selected.add(selection.photoId);
          _commentController(
            taskId,
            selection.photoId,
            fallback: selection.comment,
          );
        }
        _selectedByTask[taskId] = selected;
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load task photos: $e';
        });
      }
    }
  }

  String _keyFor(int taskId, int photoId) => '$taskId:$photoId';

  TextEditingController _commentController(
    int taskId,
    int photoId, {
    String? fallback,
  }) {
    final key = _keyFor(taskId, photoId);
    return _commentControllers.putIfAbsent(
      key,
      () => TextEditingController(text: fallback ?? ''),
    );
  }

  bool _isSelected(int taskId, int photoId) =>
      (_selectedByTask[taskId] ?? const []).contains(photoId);

  void _toggleSelection(int taskId, PhotoMeta photoMeta, bool selected) {
    final selectedList = _selectedByTask.putIfAbsent(taskId, () => []);
    if (selected) {
      if (!selectedList.contains(photoMeta.photo.id)) {
        selectedList.add(photoMeta.photo.id);
      }
      _commentController(
        taskId,
        photoMeta.photo.id,
        fallback: photoMeta.comment,
      );
    } else {
      selectedList.remove(photoMeta.photo.id);
      final key = _keyFor(taskId, photoMeta.photo.id);
      _commentControllers.remove(key)?.dispose();
    }
    setState(() {});
  }

  void _moveSelection(int taskId, int photoId, int delta) {
    final selected = _selectedByTask[taskId] ?? [];
    final index = selected.indexOf(photoId);
    if (index == -1) {
      return;
    }
    final target = index + delta;
    if (target < 0 || target >= selected.length) {
      return;
    }
    final value = selected.removeAt(index);
    selected.insert(target, value);
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final selections = <QuoteTaskPhoto>[];
      for (final group in _groups) {
        final taskId = group.group.taskId;
        if (taskId == null) {
          continue;
        }
        final selected = _selectedByTask[taskId] ?? const [];
        for (var i = 0; i < selected.length; i++) {
          final photoId = selected[i];
          final comment = _commentController(taskId, photoId).text.trim();
          selections.add(
            QuoteTaskPhoto.forInsert(
              quoteId: widget.quoteId,
              taskId: taskId,
              photoId: photoId,
              displayOrder: i,
              comment: comment,
            ),
          );
        }
      }

      await DaoQuoteTaskPhoto().replaceByQuote(widget.quoteId, selections);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Quote Task Photos'),
    content: SizedBox(width: 900, height: 600, child: _buildBody()),
    actions: [
      HMBButton(
        label: 'Cancel',
        hint: 'Close without saving task photo selections',
        enabled: !_saving,
        onPressed: () => Navigator.of(context).pop(),
      ),
      HMBButton(
        label: _saving ? 'Saving...' : 'Save',
        hint: 'Save selected task photos, comments, and ordering',
        enabled: !_saving,
        onPressed: _save,
      ),
    ],
  );

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_groups.isEmpty) {
      return const Center(child: Text('No quote tasks found.'));
    }

    return ListView(children: _groups.map(_buildTaskGroup).toList());
  }

  Widget _buildTaskGroup(_TaskPhotoGroupData groupData) {
    final group = groupData.group;
    final taskId = group.taskId!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task: ${group.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (Strings.isNotBlank(group.description))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(group.description),
              ),
            const SizedBox(height: 10),
            if (groupData.photos.isEmpty)
              const Text('No photos for this task.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < groupData.photos.length; i++)
                    _buildPhotoCard(
                      taskId: taskId,
                      index: i,
                      photoMeta: groupData.photos[i],
                      allTaskPhotos: groupData.photos,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard({
    required int taskId,
    required int index,
    required PhotoMeta photoMeta,
    required List<PhotoMeta> allTaskPhotos,
  }) {
    final selected = _isSelected(taskId, photoMeta.photo.id);
    final selectedOrder = (_selectedByTask[taskId] ?? const []).indexOf(
      photoMeta.photo.id,
    );
    final canMoveUp = selectedOrder > 0;
    final canMoveDown =
        selected &&
        selectedOrder < ((_selectedByTask[taskId] ?? const []).length - 1);

    final path = photoMeta.absolutePathTo;
    final exists = File(path).existsSync();

    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              if (!exists) {
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PhotoCarousel(photos: allTaskPhotos, initialIndex: index),
                ),
              );
            },
            child: Stack(
              children: [
                if (exists)
                  Image.file(
                    File(path),
                    width: 210,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    width: 210,
                    height: 120,
                    color: Colors.grey,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, color: Colors.white),
                  ),
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.zoom_in, color: Colors.white),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selected,
            title: Text(
              selectedOrder == -1
                  ? 'Include in quote'
                  : 'Include (#${selectedOrder + 1})',
            ),
            onChanged: (value) =>
                _toggleSelection(taskId, photoMeta, value ?? false),
          ),
          TextField(
            controller: _commentController(
              taskId,
              photoMeta.photo.id,
              fallback: photoMeta.comment,
            ),
            enabled: selected,
            decoration: const InputDecoration(
              labelText: 'Comment',
              isDense: true,
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Move up',
                onPressed: canMoveUp
                    ? () => _moveSelection(taskId, photoMeta.photo.id, -1)
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: canMoveDown
                    ? () => _moveSelection(taskId, photoMeta.photo.id, 1)
                    : null,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskPhotoGroupData {
  final QuoteLineGroup group;
  final List<PhotoMeta> photos;

  _TaskPhotoGroupData({required this.group, required this.photos});
}
