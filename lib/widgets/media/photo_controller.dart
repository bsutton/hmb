import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../crud/task/photo_crud.dart';
import '../../dao/dao_photo.dart';
import '../../entity/entity.dart';
import '../../entity/photo.dart';
import 'photo_gallery.dart';

class PhotoController<E extends Entity<E>> {
  PhotoController({required E? parent}) : _entity = parent {
    unawaited(_loadPhotos());
  }

  E? _entity;
  final List<Photo> _photos = [];

  E? get parent => _entity;

  set parent(E? parent) {
    _entity = parent;
    June.getState(PhotoLoader.new).setState();
  }

  Future<List<Photo>> get photos async {
    await _completer.future;
    return _photos;
  }

  final Completer<void> _completer = Completer<void>();

  // List to hold comment controllers for each photo
  final List<TextEditingController> _commentControllers = [];

  Future<void> _loadPhotos() async {
    if (_entity == null) {
      _completer.complete();
      return;
    }
    _photos.addAll(await DaoPhoto().getByTask(_entity!.id));

    // Initialize comment controllers if not already initialized
    if (_commentControllers.isEmpty) {
      for (final photo in _photos) {
        final controller = TextEditingController(text: photo.comment);

        _commentControllers.add(controller);
      }
    }
    _completer.complete();
  }

  /// Save comments explicitly when saving the task
  Future<void> save() async {
    await _completer.future;
    for (var i = 0; i < _commentControllers.length; i++) {
      final photo = _photos[i]..comment = _commentControllers[i].text;
      await DaoPhoto().update(photo);
    }
    PhotoGallery.notify();
  }

  void dispose() {
    for (final controller in _commentControllers) {
      controller.dispose();
    }
  }

  TextEditingController commentController(Photo photo) =>
      _commentControllers[_photos.indexOf(photo)];

  Future<void> addPhoto(Photo newPhoto) async {
    await DaoPhoto().insert(newPhoto);

    _photos.add(newPhoto);
    _commentControllers.add(TextEditingController());
    _refresh();
  }

  Future<void> deletePhoto(Photo photo) async {
    final exist = File(photo.filePath).existsSync();
    print('exists: $exist');
    // Delete the photo from the database and the disk
    await DaoPhoto().delete(photo.id);
    await File(photo.filePath).delete();
    _commentControllers.removeAt(_photos.indexOf(photo)).dispose();
    _photos.remove(photo);

    _refresh();
  }

  void _refresh() {
    June.getState(PhotoLoader.new).setState();
    PhotoGallery.notify();
  }
}
