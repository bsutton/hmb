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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:june/june.dart';

import '../../../dao/dao_photo.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/photo_meta.dart';
import '../../crud/task/photo_crud.dart';
import 'captured_photo.dart';
import 'photo_gallery.dart';

class PhotoController<E extends Entity<E>> {
  E? _entity;
  ParentType parentType;
  final bool Function(E, Photo)? filter;
  final List<PhotoMeta> _photos = [];
  // List to hold comment controllers for each photo
  final List<TextEditingController> _commentControllers = [];
  final List<String> _originalComments = [];

  PhotoController({required E? parent, required this.parentType, this.filter})
    : _entity = parent;

  Future<void> load() async {
    await _loadPhotos();
  }

  E? get parent => _entity;

  set parent(E? parent) {
    _entity = parent;
    June.getState(PhotoLoader.new).setState();
  }

  Future<List<PhotoMeta>> get photos async => _photos;

  Future<void> _loadPhotos() async {
    if (_entity == null) {
      return;
    }
    _photos.clear();
    for (final controller in _commentControllers) {
      controller.dispose();
    }
    _commentControllers.clear();
    _originalComments.clear();

    final meta = await DaoPhoto.getMetaByParent(_entity!.id, parentType);

    _photos.addAll(
      meta.where((photo) => filter?.call(_entity!, photo.photo) ?? true),
    );

    for (final photo in _photos) {
      final comment = photo.comment ?? photo.photo.comment;
      _commentControllers.add(TextEditingController(text: comment));
      _originalComments.add(comment);
    }
  }

  /// Save comments explicitly when saving the task
  Future<void> save() async {
    for (var i = 0; i < _commentControllers.length; i++) {
      final photoMeta = _photos[i];
      final updatedComment = _commentControllers[i].text.trim();
      photoMeta.comment = updatedComment;
      photoMeta.photo.comment = updatedComment;
      await DaoPhoto().update(photoMeta.photo);
      _originalComments[i] = updatedComment;
    }
    PhotoGallery.notify();
  }

  Future<void> saveComment(PhotoMeta photoMeta) async {
    final index = _indexForPhotoId(photoMeta.photo.id);
    if (index == -1) {
      return;
    }
    final updatedComment = _commentControllers[index].text.trim();
    photoMeta.comment = updatedComment;
    photoMeta.photo.comment = updatedComment;
    await DaoPhoto().update(photoMeta.photo);
    _originalComments[index] = updatedComment;
    PhotoGallery.notify();
  }

  void dispose() {
    for (final controller in _commentControllers) {
      controller.dispose();
    }
  }

  TextEditingController commentController(PhotoMeta photoMeta) =>
      _commentControllers[_indexForPhotoId(photoMeta.photo.id)];

  bool isCommentDirty(PhotoMeta photoMeta) {
    final index = _indexForPhotoId(photoMeta.photo.id);
    if (index == -1) {
      return false;
    }
    return _commentControllers[index].text.trim() != _originalComments[index];
  }

  void onCommentChanged(PhotoMeta photoMeta, String value) {
    final index = _indexForPhotoId(photoMeta.photo.id);
    if (index == -1) {
      return;
    }
    photoMeta.comment = value;
    photoMeta.photo.comment = value;
    June.getState(PhotoLoader.new).setState();
  }

  Future<void> addPhoto(PhotoMeta newPhotoMeta) async {
    await DaoPhoto().insert(newPhotoMeta.photo);

    _photos.add(newPhotoMeta);
    final comment = newPhotoMeta.comment ?? '';
    _commentControllers.add(TextEditingController(text: comment));
    _originalComments.add(comment);
    _refresh();
  }

  Future<void> deletePhoto(PhotoMeta photoMeta) async {
    await photoMeta.resolve();
    final exist = File(photoMeta.absolutePathTo).existsSync();
    print('exists: $exist');
    // Delete the photo from the database and the disk
    await DaoPhoto().delete(photoMeta.photo.id);
    await File(photoMeta.absolutePathTo).delete();
    final index = _indexForPhotoId(photoMeta.photo.id);
    if (index != -1) {
      _commentControllers.removeAt(index).dispose();
      _originalComments.removeAt(index);
      _photos.removeAt(index);
    }

    _refresh();
  }

  Future<CapturedPhoto?> takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      return null;
    }

    return CapturedPhoto.saveToHMBStorage(pickedFile.path);
  }

  void _refresh() {
    June.getState(PhotoLoader.new).setState();
    PhotoGallery.notify();
  }

  int _indexForPhotoId(int photoId) =>
      _photos.indexWhere((photoMeta) => photoMeta.photo.id == photoId);
}
