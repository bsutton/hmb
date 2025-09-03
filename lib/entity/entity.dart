/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

abstract class Entity<T extends Entity<T>> {
  int id;
  DateTime modifiedDate;
  final DateTime createdDate;

  Entity({required this.id, DateTime? createdDate, DateTime? modifiedDate})
    : createdDate = createdDate ?? DateTime.now(),
      modifiedDate = modifiedDate ?? DateTime.now();

  // For new rows
  Entity.forInsert()
    : id = -1,
      createdDate = DateTime.now(),
      modifiedDate = DateTime.now();

  Map<String, Object?> toMap();

  @override
  bool operator ==(covariant Entity<T> other) {
    if (identical(this, other)) {
      return true;
    }
    return other.id == id &&
        other.createdDate == createdDate &&
        other.modifiedDate == modifiedDate;
  }

  @override
  int get hashCode => Object.hash(id, createdDate, modifiedDate);
}
