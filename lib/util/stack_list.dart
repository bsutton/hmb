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


import 'dart:collection';

///
/// A classic Stack of items with a push and pop method.
///
class StackList<T> {
  StackList();

  ///
  /// Creates a stack from [initialStack]
  /// by pushing each element of the list
  /// onto the stack from first to last.
  StackList.fromList(List<T> initialStack) {
    for (final item in initialStack) {
      push(item);
    }
  }
  Queue<T> stack = Queue();

  void push(T item) {
    stack.addFirst(item);
  }

  T pop() => stack.removeFirst();

  /// returns the item on the top of the stack
  /// but does not remove the item.
  T peek() => stack.first;
}
