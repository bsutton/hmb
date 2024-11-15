import 'dart:async';
import 'dart:io';

import 'package:dcli_core/dcli_core.dart';
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:june/june.dart';
import 'package:strings/strings.dart';

import '../../dao/dao_photo.dart';
import '../../entity/entity.dart';
import '../../entity/photo.dart';
import '../../util/photo_meta.dart';
import '../../widgets/media/full_screen_photo_view.dart';
import '../../widgets/media/photo_controller.dart';
import '../../widgets/media/photo_gallery.dart';

class PhotoCrud<E extends Entity<E>> extends StatefulWidget {
  const PhotoCrud(
      {required this.parentName,
      required this.parentType,
      required this.controller,
      super.key});

  final String parentName;
  final ParentType parentType;
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
              builder: (context, photoMetas) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAddButton(widget.controller.parent, photoMetas),
                      _buildPhotoCRUD(photoMetas),
                    ],
                  )));
    }
  }

  /// Build the take photo button
  Widget _buildAddButton(E? parent, List<PhotoMeta>? photoMetas) => IconButton(
        icon: const Icon(Icons.camera_alt),
        onPressed: () async {
          final capturedPhoto = await widget.controller.takePhoto();
          if (capturedPhoto != null) {
            // Insert the photo metadata into the database
            final newPhoto = Photo.forInsert(
              parentId: parent!.id,
              parentType: widget.parentType.name,
              filePath: capturedPhoto.relativePath,
              comment: '',
            );
            await widget.controller
                .addPhoto(PhotoMeta(photo: newPhoto, title: '', comment: null));
          }
        },
      );

  /// Build the photo CRUD
  Widget _buildPhotoCRUD(List<PhotoMeta>? photoMetas) => Column(
        mainAxisSize: MainAxisSize.min,
        children: photoMetas!
            .map((photoMeta) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _showPhoto(photoMeta),
                    _buildCommentField(photoMeta),
                    _buildDeleteButton(photoMeta),
                  ],
                ))
            .toList(),
      );

  /// Display the photo with a 'Icon in the corner
  /// which when tapped will show the full screen photo
  /// with zoom/pan ability.
  Widget _showPhoto(PhotoMeta photoMeta) => FutureBuilderEx(
      // ignore: discarded_futures
      future: photoMeta.resolve(),
      builder: (context, path) => Stack(
            children: [
              if (exists(path!))
                Image.file(File(path))
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
                    if (exists(path) && mounted) {
                      await FullScreenPhotoViewer.show(
                          context: context,
                          imagePath: path,
                          title: photoMeta.title,
                          comment: photoMeta.comment);
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
          ));

  IconButton _buildDeleteButton(PhotoMeta photoMeta) => IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          await _showConfirmDeleteDialog(context, photoMeta);
          PhotoGallery.notify();
        },
      );

  Widget _buildCommentField(PhotoMeta photoMeta) {
    final commentControlller = widget.controller.commentController(photoMeta);
    return TextField(
      controller: commentControlller,
      decoration: const InputDecoration(labelText: 'Comment'),
      maxLines: null, // Allows the field to grow as needed
      onChanged: (value) {
        // Update comment immediately when text changes
        photoMeta.comment = value;
      },
    );
  }

  /// currently causing flutter to crash.
  Future<void> _showConfirmDeleteDialog(
      BuildContext context, PhotoMeta photoMeta) async {
    final pathToPhoto = photoMeta.absolutePathTo;
    if (context.mounted) {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Photo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.file(File(pathToPhoto),
                  width: 100, height: 100), // Thumbnail of the photo
              if (Strings.isNotBlank(photoMeta.comment))
                Text(photoMeta.photo.comment),
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
                await widget.controller.deletePhoto(photoMeta);
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

  // Future<void> _showFullScreenPhoto(BuildContext context, String imagePath,
  //     String taskName, String comment) async {
  //   await context.push('/photo_viewer', extra: {
  //     'imagePath': imagePath,
  //     'taskName': taskName,
  //     'comment': comment,
  //   });
  // }
}

class PhotoLoader extends JuneState {}
