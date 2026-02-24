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

import 'entity.dart';

class JobAttachment extends Entity<JobAttachment> {
  int jobId;
  String filePath;
  String displayName;

  JobAttachment({
    required super.id,
    required this.jobId,
    required this.filePath,
    required this.displayName,
    required super.createdDate,
    required super.modifiedDate,
  }) : super();

  JobAttachment.forInsert({
    required this.jobId,
    required this.filePath,
    required this.displayName,
  }) : super.forInsert();

  JobAttachment copyWith({int? jobId, String? filePath, String? displayName}) =>
      JobAttachment(
        id: id,
        jobId: jobId ?? this.jobId,
        filePath: filePath ?? this.filePath,
        displayName: displayName ?? this.displayName,
        createdDate: createdDate,
        modifiedDate: DateTime.now(),
      );

  factory JobAttachment.fromMap(Map<String, dynamic> map) => JobAttachment(
    id: map['id'] as int,
    jobId: map['job_id'] as int,
    filePath: map['file_path'] as String,
    displayName: map['display_name'] as String,
    createdDate: DateTime.parse(map['created_date'] as String),
    modifiedDate: DateTime.parse(map['modified_date'] as String),
  );

  @override
  Map<String, dynamic> toMap() => {
    'id': id,
    'job_id': jobId,
    'file_path': filePath,
    'display_name': displayName,
    'created_date': createdDate.toIso8601String(),
    'modified_date': modifiedDate.toIso8601String(),
  };
}
