import 'dart:math';

class MutablePoint {
  double x;
  double y;
  bool pinned;

  MutablePoint(this.x, this.y) : pinned = false;

  MutablePoint.xy(int x, int y)
    : x = x.toDouble(),
      y = y.toDouble(),
      pinned = false;

  double get length => sqrt(x * x + y * y);

  MutablePoint operator *(double factor) =>
      MutablePoint(x * factor, y * factor);
}
