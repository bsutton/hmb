import 'package:flutter/widgets.dart';

typedef OnSwipe = void Function();

class HMBSwipeLeft extends StatelessWidget {
  const HMBSwipeLeft({required this.child, required this.onSwipe, super.key});

  final Widget child;
  final OnSwipe onSwipe;

  @override
  Widget build(BuildContext context) => GestureDetector(
      onHorizontalDragEnd: (details) {
        // Check if the swipe is from left to right
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          onSwipe();
        }
      },
      child: child);
}
