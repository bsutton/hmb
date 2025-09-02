extension FutureEx on Future<void> {
  /// Call each function in turn, waiting for the prior one
  /// to complete before starting the next one.
  static Future<void>? chain(List<Future<void> Function()> list) async {
    for (final function in list) {
      await function();
    }
  }
}
