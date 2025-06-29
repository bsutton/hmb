/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

enum JobStatusEnum { finalised, preStart, progressing, onHold }

extension JobStatusEnumExtension on JobStatusEnum {
  String get name {
    switch (this) {
      case JobStatusEnum.finalised:
        return 'finalised';
      case JobStatusEnum.preStart:
        return 'preStart';
      case JobStatusEnum.progressing:
        return 'progressing';
      case JobStatusEnum.onHold:
        return 'onHold';
    }
  }

  static JobStatusEnum fromName(String name) {
    switch (name) {
      case 'finalised':
        return JobStatusEnum.finalised;
      case 'preStart':
        return JobStatusEnum.preStart;
      case 'progressing':
        return JobStatusEnum.progressing;
      case 'onHold':
        return JobStatusEnum.onHold;
      default:
        return JobStatusEnum.preStart;
    }
  }
}
