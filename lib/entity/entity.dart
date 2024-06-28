abstract class Entity<T> {
  Entity(
      {required this.id,
      required this.createdDate,
      required this.modifiedDate});
  Entity.forInsert()
      : id = -1,
        createdDate = DateTime.now(),
        modifiedDate = DateTime.now();

  Entity.forUpdate({required Entity<T> entity})
      : id = entity.id,
        createdDate = entity.createdDate,
        modifiedDate = DateTime.now();

  int id;
  DateTime createdDate;
  DateTime modifiedDate;

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(covariant Entity<T> other) {
    if (identical(this, other) ||
        other.id == id &&
            other.createdDate == createdDate &&
            other.modifiedDate == modifiedDate) {
      return true;
    }
    return false;
  }

  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => Object.hash(id, createdDate, modifiedDate);

  Map<String, Object?> toMap();
}
