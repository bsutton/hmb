import '../../entity/entity.dart';

abstract class DaoJoinAdaptor<C extends Entity<C>, P extends Entity<P>> {
  Future<List<C>> getByParent(P? parent);
  Future<void> insertForParent(C child, P parent);
  Future<void> deleteFromParent(C child, P parent);

  Future<void> setAsPrimary(C child, P parent);
}
