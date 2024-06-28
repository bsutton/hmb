extension ListEx<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }

  T? lastWhereOrNull(bool Function(T element) test) {
    final iterator = this.iterator;
    // Potential result during first loop.
    T result;
    do {
      if (!iterator.moveNext()) {
        return null;
      }
      result = iterator.current;
    } while (!test(result));
    // Now `result` is actual result, unless a later one is found.
    while (iterator.moveNext()) {
      final current = iterator.current;
      if (test(current)) {
        result = current;
      }
    }
    return result;
  }
}
