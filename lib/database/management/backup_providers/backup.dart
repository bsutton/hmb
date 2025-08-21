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

class Backup {
  String id;
  DateTime when;
  String pathTo;
  String size;
  String status;
  String error;

  Backup({
    required this.id,
    required this.when,
    required this.pathTo,
    required this.size,
    required this.status,
    required this.error,
  });
}
