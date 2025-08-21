/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton.
 All Rights Reserved.
*/

import 'package:flutter/material.dart';

import '../../../dao/dao_customer.dart';
import '../../../dao/dao_job.dart';
import '../../../entity/entity.g.dart';
import '../../crud/customer/edit_customer_screen.dart';
import '../../crud/job/edit_job_screen.dart';
import '../../widgets/hmb_toast.dart';
import '../hmb_chip.dart';

/// Generic entity chip that resolves [id] to an entity label and
/// (by default) navigates to the editor when tapped.
class HMBEntityChip<E extends Entity<E>> extends StatelessWidget {
  final int id;
  final Future<E?> Function() loader;
  final String fallbackLabel;
  final HMBChipTone tone;
  final IconData? icon;
  final String? prefix;
  final String Function(E entity) format;

  /// Override navigation. If null, default navigation is used.
  final void Function(BuildContext context, E entity)? onTap;

  /// Default navigation used when [onTap] is null.
  final void Function(BuildContext context, E entity) onTapDefault;

  const HMBEntityChip._({
    required this.id,
    required this.loader,
    required this.fallbackLabel,
    required this.onTapDefault,
    required this.format,
    this.tone = HMBChipTone.neutral,
    this.icon,
    this.onTap,
    this.prefix,
    super.key,
  });

  /// Static builder for Job
  static HMBEntityChip<Job> job({
    required int id,
    required String Function(Job entity) format,
    String? prefix,
    HMBChipTone tone = HMBChipTone.neutral,
    IconData? icon = Icons.work,
    void Function(BuildContext, Job entity)? onTap,
    Key? key,
  }) => HMBEntityChip<Job>._(
    id: id,
    key: key,
    tone: tone,
    icon: icon,
    format: format,
    prefix: prefix ?? 'Job',
    loader: () => DaoJob().getById(id),
    fallbackLabel: '#$id',
    onTapDefault: (ctx, e) async {
      await Navigator.push(
        ctx,
        MaterialPageRoute<void>(builder: (_) => JobEditScreen(job: e)),
      );
    },
    onTap: onTap,
  );

  /// Static builder for Customer
  static HMBEntityChip<Customer> customer({
    required int id,
    required String Function(Customer entity) format,
    String? prefix,
    HMBChipTone tone = HMBChipTone.neutral,
    IconData? icon = Icons.person,
    void Function(BuildContext, Customer entity)? onTap,
    Key? key,
  }) => HMBEntityChip<Customer>._(
    id: id,
    key: key,
    tone: tone,
    icon: icon,
    format: format,
    prefix: prefix ?? 'Customer',
    loader: () => DaoCustomer().getById(id),
    fallbackLabel: '#$id',
    onTapDefault: (ctx, e) async {
      await Navigator.push(
        ctx,
        MaterialPageRoute<void>(
          builder: (_) => CustomerEditScreen(customer: e),
        ),
      );
    },
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<E?>(
    future: loader(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return HMBChip(
          label: prefix != null ? '$prefix…' : 'Loading…',
          tone: tone,
          icon: Icons.hourglass_top,
        );
      }

      if (snap.hasError) {
        return HMBChip(
          label: prefix != null ? '$prefix error' : 'Error',
          tone: HMBChipTone.warning,
          icon: Icons.error_outline,
          onTap: () => HMBToast.error(snap.error.toString()),
        );
      }

      final entity = snap.data;
      if (entity == null) {
        final label = prefix != null
            ? '$prefix $fallbackLabel (missing)'
            : 'Missing $fallbackLabel';
        return HMBChip(
          label: label,
          tone: HMBChipTone.warning,
          icon: Icons.help_outline,
        );
      }

      final text = format(entity);
      return HMBChip(
        label: prefix != null ? '$prefix: $text' : text,
        tone: tone,
        icon: icon,
        onTap: () {
          final handler = onTap ?? onTapDefault;
          handler(context, entity);
        },
      );
    },
  );
}
