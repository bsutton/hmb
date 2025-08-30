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
