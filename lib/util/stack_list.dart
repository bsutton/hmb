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

  /// returns the item onf the top of the stack
  /// but does not remove the item.
  T peek() => stack.first;
}
