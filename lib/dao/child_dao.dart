import '../entity/entity.dart';

abstract class ChildDao<C extends Entity<C>, P extends Entity<P>> {
  /// delete the child owned by [parent]
  Future<void> delete(C child, P parent);

  /// insert the child owned by [parent]
  Future<void> insert(C child, P parent);
}
