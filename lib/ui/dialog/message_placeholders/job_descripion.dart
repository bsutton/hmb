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

import '../../../entity/job.dart';
import 'job_source.dart';
import 'place_holder.dart';

class JobDescription extends PlaceHolder<Job> {
  JobDescription({required this.jobSource})
    : super(name: tagName, base: tagBase, source: jobSource);

  static const tagName = 'job.description';

  static const tagBase = 'job';
  final JobSource jobSource;

  @override
  Future<String> value() async {
    final job = jobSource.value;
    return job?.description ?? '';
  }
}
