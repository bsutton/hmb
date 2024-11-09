import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:june/june.dart';
import 'package:path_provider/path_provider.dart';

import '../../dao/dao_task.dart';
import '../../entity/entity.dart';
import '../../entity/photo.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/media/photo_gallery.dart';

class PhotoCrud<E extends Entity<E>> extends StatefulWidget {
  const PhotoCrud(
      {required this.parentName, required this.controller, super.key});

  final String parentName;
  final PhotoController<E> controller;

  @override
  State<PhotoCrud> createState() => _PhotoCrudState<E>();
}

class _PhotoCrudState<E extends Entity<E>> extends State<PhotoCrud<E>> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.parent == null) {
      return Center(
          child: Text('To Add a Photo - Save the ${widget.parentName} First'));
    }
    // Display photos and allow adding comments and deletion
    else {
      return JuneBuilder(PhotoLoader.new,
          builder: (context) => FutureBuilderEx(
              // ignore: discarded_futures
              future: widget.controller.photos,
              builder: (context, photos) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAddButton(widget.controller.parent, photos),
                      _buildPhotoCRUD(photos),
                    ],
                  )));
    }
  }

  /// Build the take photo button
  Widget _buildAddButton(E? parent, List<Photo>? photos) => IconButton(
        icon: const Icon(Icons.camera_alt),
        onPressed: () async {
          final photoFile = await takePhoto();
          if (photoFile != null) {
            // Insert the photo metadata into the database
            final newPhoto = Photo.forInsert(
              taskId: parent!.id,
              filePath: photoFile.path,
              comment: '',
            );
            await widget.controller.addPhoto(newPhoto);
          }
        },
      );

  /// Build the photo CRUD
  Widget _buildPhotoCRUD(List<Photo>? photos) => Column(
        mainAxisSize: MainAxisSize.min,
        children: photos!
            .map((photo) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _showPhoto(photo),
                    _buildCommentField(photo),
                    _buildDeleteButton(photo),
                  ],
                ))
            .toList(),
      );

  /// Display the photo with a 'Icon in the corner
  /// which when tapped will show the full screen photo
  /// with zoom/pan ability.
  Stack _showPhoto(Photo photo) {
    final file = File(photo.filePath);
    final isFileExist = file.existsSync();

    return Stack(
      children: [
        if (isFileExist)
          Image.file(file)
        else
          Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey,
            child: const Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 80,
            ),
          ),
        Positioned(
          right: 0,
          child: GestureDetector(
            // Show full screen photo when tapped, only if the file exists
            onTap: () async {
              if (isFileExist) {
                final task = await DaoTask().getById(photo.taskId);
                if (mounted) {
                  await _showFullScreenPhoto(
                      context, photo.filePath, task!.name, photo.comment);
                }
              }
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconButton _buildDeleteButton(Photo photo) => IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          await _showConfirmDeleteDialog(context, photo);
          PhotoGallery.notify();
        },
      );

  Widget _buildCommentField(Photo photo) {
    final commentControlller = widget.controller.commentController(photo);
    return TextField(
      controller: commentControlller,
      decoration: const InputDecoration(labelText: 'Comment'),
      maxLines: null, // Allows the field to grow as needed
      onChanged: (value) {
        // Update comment immediately when text changes
        photo.comment = value;
      },
    );
  }

  /// currently causing flutter to crash.
  Future<void> _showConfirmDeleteDialog(
      BuildContext context, Photo photo) async {
    if (context.mounted) {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.file(File(photo.filePath),
                  width: 100, height: 100), // Thumbnail of the photo
              if (photo.comment.isNotEmpty) Text(photo.comment),
              const SizedBox(height: 10),
              const Text('Are you sure you want to delete this photo?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await widget.controller.deletePhoto(photo);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showFullScreenPhoto(BuildContext context, String imagePath,
      String taskName, String comment) async {
    await context.push('/photo_viewer', extra: {
      'imagePath': imagePath,
      'taskName': taskName,
      'comment': comment,
    });
  }

  Future<File?> takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      return null;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = pickedFile.path.split('/').last;
    final savedImage =
        await File(pickedFile.path).copy('${appDir.path}/$fileName');

    final exist = File(savedImage.path).existsSync();
    print('exists: $exist');

    return savedImage;
  }
}

class PhotoLoader extends JuneState {}
