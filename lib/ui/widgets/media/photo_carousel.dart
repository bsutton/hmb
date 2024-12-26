import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:photo_view/photo_view.dart';

import '../../../util/photo_meta.dart';
import '../layout/hmb_spacer.dart';
import '../text/hmb_text_themes.dart';

class PhotoCarousel extends StatefulWidget {
  const PhotoCarousel({
    required this.photos,
    required this.initialIndex,
    super.key,
  });

  final List<PhotoMeta> photos;
  final int initialIndex;

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Moves the carousel to [newIndex] with animation.
  Future<void> _scrollToIndex(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.photos.length) {
      return;
    }

    setState(() => _currentIndex = newIndex);
    await _pageController.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Detects scroll direction (mouse wheel) and navigates accordingly.
  Future<void> _handleScroll(double offset) async {
    // Scroll down => next photo
    if (offset < 0 && _currentIndex < widget.photos.length - 1) {
      await _scrollToIndex(_currentIndex + 1);
    }
    // Scroll up => previous photo
    else if (offset > 0 && _currentIndex > 0) {
      await _scrollToIndex(_currentIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              // Right arrow => next photo
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                unawaited(_scrollToIndex(_currentIndex + 1));
                return KeyEventResult.handled;
              }
              // Left arrow => previous photo
              else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                unawaited(_scrollToIndex(_currentIndex - 1));
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: (event) async {
              if (event is PointerScrollEvent) {
                await _handleScroll(event.scrollDelta.dy);
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitle(context),
                Expanded(
                  child: Stack(
                    children: [
                      // The PageView displays one photo per page.
                      _buildPhoto(),
                      // Title and optional comment
                      // Give extra space on the right (right: 80) so it doesn't overlap buttons.

                      // Previous & Next FABs at the bottom
                      Positioned(
                        bottom: 40,
                        left: 20,
                        right: 20,
                        child: _buildNextPrevButtons(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  PageView _buildPhoto() => PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photoMeta = widget.photos[index];
          return PhotoView(
            imageProvider: FileImage(File(photoMeta.absolutePathTo)),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            initialScale: PhotoViewComputedScale.contained,
          );
        },
      );

  Row _buildNextPrevButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          FloatingActionButton(
            heroTag: 'previousPhotoBtn',
            onPressed: _currentIndex == 0
                ? null
                : () async => _scrollToIndex(_currentIndex - 1),
            backgroundColor:
                _currentIndex == 0 ? Colors.grey[700] : Colors.purple,
            child: const Icon(Icons.arrow_back),
          ),

          // The new count Text, e.g. "2/5"
          Text(
            '${_currentIndex + 1}/${widget.photos.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Next button
          FloatingActionButton(
            heroTag: 'nextPhotoBtn',
            onPressed: _currentIndex == widget.photos.length - 1
                ? null
                : () async => _scrollToIndex(_currentIndex + 1),
            backgroundColor: _currentIndex == widget.photos.length - 1
                ? Colors.grey[700]
                : Colors.purple,
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      );

  Column _buildTitle(BuildContext context) => Column(
        children: [
          Row(children: [
            const HMBSpacer(width: true),
            Expanded(
              child: HMBTextLine(
                'Task: ${widget.photos[_currentIndex].title}',
              ),
            ),
            _buildCopyClose(context)
          ]),
          HMBTextLine(
            widget.photos[_currentIndex].comment ?? '',
          ),
        ],
      );

  Row _buildCopyClose(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.content_copy, color: Colors.white, size: 30),
            onPressed: () async {
              try {
                await Pasteboard.writeFiles([
                  widget.photos[_currentIndex].absolutePathTo,
                ]);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Image copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to copy image to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
}
