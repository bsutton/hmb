/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:ui';

import '../util/hex_to_color.dart';
import 'entity.g.dart';

enum JobStatus {
  prospecting(
    id: 'Prospecting',
    displayName: 'Prospecting',
    description: 'A customer has contacted us about a potential job',
    colorCode: '#ADD8E6',
    stage: JobStatusStage.preStart,
    schedulingAllowed: false,
    ordinal: 1,
  ),
  quoting(
    id: 'Quoting',
    displayName: 'Quoting',
    description: 'Preparing a quote for the job',
    colorCode: '#ADD8E6',
    stage: JobStatusStage.preStart,
    schedulingAllowed: false,
    ordinal: 2,
  ),
  awaitingApproval(
    id: 'AwaitingApproval',
    displayName: 'Awaiting Approval',
    description: 'Waiting on the client to approve quote',
    colorCode: '#ADD8E6',
    stage: JobStatusStage.preStart,
    schedulingAllowed: false,
    ordinal: 3,
  ),
  awaitingPayment(
    id: 'AwaitingPayment',
    displayName: 'Awaiting Payment',
    description: 'Approved but awaiting payment',
    colorCode: '#FFD700',
    stage: JobStatusStage.preStart,
    schedulingAllowed: true,
    ordinal: 4,
  ),
  toBeScheduled(
    id: 'ToBeScheduled',
    displayName: 'To be Scheduled',
    description: 'Customer agreed to proceed but no start date set',
    colorCode: '#FFFFE0',
    stage: JobStatusStage.preStart,
    schedulingAllowed: true,
    ordinal: 5,
  ),
  scheduled(
    id: 'Scheduled',
    displayName: 'Scheduled',
    description: 'Job has been approved and scheduled',
    colorCode: '#FFD700',
    stage: JobStatusStage.progressing,
    schedulingAllowed: true,
    ordinal: 6,
  ),
  inProgress(
    id: 'InProgress',
    displayName: 'In Progress',
    description: 'The Job is currently in progress',
    colorCode: '#87CEFA',
    stage: JobStatusStage.progressing,
    schedulingAllowed: true,
    ordinal: 7,
  ),
  onHold(
    id: 'OnHold',
    displayName: 'On Hold',
    description: 'The Job is on hold',
    colorCode: '#FAFAD2',
    stage: JobStatusStage.onHold,
    schedulingAllowed: true,
    ordinal: 8,
  ),
  awaitingMaterials(
    id: 'AwaitingMaterials',
    displayName: 'Awaiting Materials',
    description: 'The job is paused until materials are available',
    colorCode: '#D3D3D3',
    stage: JobStatusStage.onHold,
    schedulingAllowed: true,
    ordinal: 9,
  ),
  // progressPayment(
  //   id: 'ProgressPayment',
  //   displayName: 'Progress Payment',
  //   description: 'Job stage complete — progress payment required',
  //   colorCode: '#F08080',
  //   stage: JobStatusStage.finalised,
  //   ordinal: 9,
  // ),
  completed(
    id: 'Completed',
    displayName: 'Completed',
    description: 'The Job is completed',
    colorCode: '#90EE90',
    stage: JobStatusStage.finalised,
    schedulingAllowed: false,
    ordinal: 10,
  ),

  toBeBilled(
    id: 'ToBeBilled',
    displayName: 'To be Billed',
    description: 'Completed — needs to be billed',
    colorCode: '#FFA07A',
    stage: JobStatusStage.finalised,
    schedulingAllowed: false,
    ordinal: 11,
  ),
  rejected(
    id: 'Rejected',
    displayName: 'Rejected',
    description: 'The Job was rejected by the Customer',
    colorCode: '#FFB6C1',
    stage: JobStatusStage.finalised,
    schedulingAllowed: false,
    ordinal: 12,
  );

  const JobStatus({
    required this.id,
    required this.displayName,
    required this.description,
    required this.colorCode,
    required this.stage,
    required this.schedulingAllowed,
    required this.ordinal,
  });

  final String id;
  final String displayName;
  final String description;
  final String colorCode;
  final JobStatusStage stage;
  final int ordinal;
  // JobStatus' that can be
  // scheduled.
  final bool schedulingAllowed;

  static JobStatus get startingStatus => JobStatus.prospecting;

  static JobStatus fromId(String id) => values.firstWhere(
    (e) => e.id == id,
    orElse: () => JobStatus.startingStatus,
  );

  Color getColour() => hexToColor(colorCode);

  static List<JobStatus> byOrdinal() => values.toList()
    ..sort((a, b) => a.ordinal - b.ordinal)
    ..toList();

  static Iterable<JobStatus> preStart() =>
      values.where((status) => status.stage == JobStatusStage.preStart);

  static bool canBeAwaitingApproved(Job job) =>
      job.status == JobStatus.prospecting || job.status == JobStatus.quoting;

  /// Returns a list of JobStatus' that can be scheduled.
  static Iterable<JobStatus> canBeScheduled() =>
      values.where((status) => status.schedulingAllowed);

  @override
  String toString() => 'id: $id, name: $name, description: $description';
}
