/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// import 'package:sms_advanced/sms_advanced.dart' hide SimCard;

// Future<List<mobile.SimCard>> getSimCards() async {
//   List<mobile.SimCard>? cards;

//   if (!kIsWeb && Platform.isAndroid) {
//     await _requestPermissions();

//     cards = await mobile.MobileNumber.getSimCards;
//     // cards =  SimCardsProvider().getSimCards();
//   }
//   return cards ?? [];
// }

// Future<void> _requestPermissions() async {
//   var status = await Permission.phone.status;
//   if (!status.isGranted) {
//     status = await Permission.phone.request();
//   }

//   // if (!(await mobile.MobileNumber.hasPhonePermission)) {
//   if (status.isGranted) {
//     await mobile.MobileNumber.requestPhonePermission;
//   }

//   // try {
//   //   final _mobileNumber = (await mobile.MobileNumber.mobileNumber)!;
//   //   print(_mobileNumber);
//   //   print(await mobile.MobileNumber.getSimCards);
//   // } on PlatformException catch (e) {
//   //   print("Failed to get mobile number because of '${e.message}'");
//   // }

//   // final smsStatus = await Permission.phoneStatus.status;
//   // if (smsStatus.isDenied) {
//   //   final smsResult = await Permission.phoneStatus.request();
//   //   if (smsResult.isDenied) {
//   //     throw Exception(
//   //  'Phone Status permission is required to get device ID');
//   //   }
//   // }
//   // final phoneStatus = await Permission.phone.status;
//   // if (phoneStatus.isDenied) {
//   //   final phoneResult = await Permission.phone.request();
//   //   if (phoneResult.isDenied) {
//   //     throw Exception('Phone permission is required to get device ID');
//   //   }
//   // }
// }
