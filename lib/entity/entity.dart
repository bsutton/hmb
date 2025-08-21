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

abstract class Entity<T> {
  int id;
  DateTime createdDate;
  DateTime modifiedDate;

  Entity({
    required this.id,
    required this.createdDate,
    required this.modifiedDate,
  });
  Entity.forInsert()
    : id = -1,
      createdDate = DateTime.now(),
      modifiedDate = DateTime.now();

  Entity.forUpdate({required Entity<T> entity})
    : id = entity.id,
      createdDate = entity.createdDate,
      modifiedDate = DateTime.now();

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
