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

// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:flutter/material.dart';

import '../../entity/task.dart';
import '../crud/base_nested/list_nested_screen.dart';
import '../crud/time_entry/list_time_entry_screen.dart';
import 'hmb_child_crud_card.dart';
import 'hmb_start_time_entry.dart';

// class HBMCrudTimeEntry extends StatelessWidget {
//   const HBMCrudTimeEntry({
//     required this.parent,
//     required this.parentTitle,
//     super.key,
//   });

//   final Parent<Task> parent;
//   final String parentTitle;

//   @override
//   Widget build(BuildContext context) => HMBChildCrudCard(
//       headline: 'Time Entries',
//       crudListScreen: TimeEntryListScreen(
//         parent: parent,
//       ));
// }

class HMBCrudTimeEntry extends StatefulWidget {
  const HMBCrudTimeEntry({
    required this.parentTitle,
    required this.parent,
    super.key,
  });

  final String parentTitle;
  final Parent<Task> parent;

  @override
  HMBCrudTimeEntryState createState() => HMBCrudTimeEntryState();
}

class HMBCrudTimeEntryState extends State<HMBCrudTimeEntry> {
  Future<void> refresh() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      HMBStartTimeEntry(task: widget.parent.parent, onStart: (job) {}),

      HMBChildCrudCard(
        headline: 'Time Entries',
        crudListScreen: TimeEntryListScreen(parent: widget.parent),
      ),
      // )
    ],
  );
}

// FutureBuilder<List<TimeEntry>>(
//       // ignore: discarded_futures
//       future: DaoTimeEntry().getByTask(widget.parent.parent),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         } else if (snapshot.hasError) {
//           return Center(child: Text('Error: ${snapshot.error}'));
//         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(child: Text('No time entries found.'));
//         } else {
//           return ListView.builder(
//             shrinkWrap: true,
//             itemCount: snapshot.data!.length,
//             itemBuilder: (context, index) {
//               final timeEntry = snapshot.data![index];
//               return ListTile(
//                 title: Text(
//'''${timeEntry.startTime.toLocal()} - '''
//'''${timeEntry.endTime?.toLocal() ?? 'Ongoing'}'''),
//                 subtitle: Text(
//                     '''Duration:
//${_formatDuration(timeEntry.startTime, timeEntry.endTime)}'''),
//               );
//             },
//           );
//         }
//       },
//     );

// String _formatDuration(DateTime startTime, DateTime? endTime) {
//   if (endTime == null) {
//     return 'Ongoing';
//   }
//   return formatDuration(endTime.difference(startTime));
// }

// class TimeEntryReload extends JuneState {
//   TimeEntryReload();
// }
