// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:hmb/crud/job/job_edit_screen.dart';
// import 'package:hmb/dao/dao_customer.dart';
// import 'package:hmb/dao/dao_job.dart';
// import 'package:hmb/dao/dao_job_status.dart';
// import 'package:hmb/entity/job.dart';
// import 'package:mockito/mockito.dart';


// // Create mock classes for the DAOs you interact with
// class MockDaoJob extends Mock implements DaoJob {}

// class MockDaoCustomer extends Mock implements DaoCustomer {}

// class MockDaoJobStatus extends Mock implements DaoJobStatus {}

// void main() {
//   group('JobEditScreen Tests', () {
//     late MockDaoJob mockDaoJob;
//     late MockDaoCustomer mockDaoCustomer;
//     late MockDaoJobStatus mockDaoJobStatus;

//     setUp(() {
//       mockDaoJob = MockDaoJob();
//       mockDaoCustomer = MockDaoCustomer();
//       mockDaoJobStatus = MockDaoJobStatus();
//     });

//     Future<void> pumpJobEditScreen(WidgetTester tester) async {
//       await tester.pumpWidget(
//         MaterialApp(
//           home: Scaffold(
//             body: JobEditScreen(
//               job: null,
//             ),
//           ),
//         ),
//       );
//     }

//     testWidgets('should display empty fields for a new job', (tester) async {
//       await pumpJobEditScreen(tester);

//       expect(find.byType(TextField),
//           findsNWidgets(3)); // Summary, HourlyRate, CallOutFee
//       expect(find.text('Job Summary'), findsOneWidget);
//       expect(find.text('Hourly Rate'), findsOneWidget);
//       expect(find.text('Call Out Fee'), findsOneWidget);
//     });

//     testWidgets('should create a new job successfully', (tester) async {
//       await pumpJobEditScreen(tester);

//       // Simulate entering text into input fields
//       await tester.enterText(find.byKey(const Key('jobSummary')), 'Test Job');
//       await tester.enterText(find.byKey(const Key('hourlyRate')), '50');
//       await tester.enterText(find.byKey(const Key('callOutFee')), '20');

//       // Simulate tapping the save button
//       final saveButton = find.text('Save');
//       await tester.tap(saveButton);
//       await tester.pumpAndSettle();

//       // Verify that the job was inserted into the DAO
//       final captured = verify(mockDaoJob.insert(captureAny)).captured;
//       expect(captured, isNotEmpty);
//       final job = captured.first as Job;
//       expect(job.summary, 'Test Job');
//       expect(job.hourlyRate!.amount, 50);
//       expect(job.callOutFee!.amount, 20);
//     });

//     testWidgets('should show error when job creation fails', (tester) async {
//       when(mockDaoJob.insert(any)).thenThrow(Exception('Insert failed'));

//       await pumpJobEditScreen(tester);

//       // Simulate entering text into input fields
//       await tester.enterText(find.byKey(const Key('jobSummary')), 'Test Job');
//       await tester.enterText(find.byKey(const Key('hourlyRate')), '50');
//       await tester.enterText(find.byKey(const Key('callOutFee')), '20');

//       // Simulate tapping the save button
//       final saveButton = find.text('Save');
//       await tester.tap(saveButton);
//       await tester.pumpAndSettle();

//       // Check for error message
//       expect(find.text('Insert failed'), findsOneWidget);
//     });
//   });
// }
