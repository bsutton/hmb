/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

enum JobStatusStage {
  preStart('Pre Start'),
  progressing('Progressing'),
  onHold('On Hold'),
  finalised('Finalised');

  const JobStatusStage(this.name);

  final String name;

  static final Map<String, JobStatusStage> _nameMap = {
    for (var e in JobStatusStage.values) e.name: e,
  };

  static JobStatusStage fromName(String name) =>
      _nameMap[name] ?? JobStatusStage.preStart;
}
