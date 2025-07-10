/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';
import 'package:june/june.dart';

import 'dashboard.dart';

/// Holds primary and optional secondary values for a dashlet
class DashletValue<T> {
  const DashletValue(this.value, [this.secondValue]);
  final T value;
  final String? secondValue;
}

typedef DashletWidgetBuilder<T> =
    Widget Function(BuildContext context, DashletValue<T> dv);

/// Maximum size constraints for dashlets (desktop screens)
const double kDashletMaxWidth = 300;
const double kDashletMaxHeight = 300;

/// A reusable dashlet card widget that reloads its data when the dashboard resumes.
/// Supports an optional compact mode for embedding in tighter UIs (e.g. job card).
class DashletCard<T> extends StatefulWidget {
  const DashletCard({
    required this.label,
    required this.icon,
    required this.dashletValue,
    this.route,
    this.widgetBuilder,
    this.builder,
    this.onTapOverride,
    this.compact = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final Future<DashletValue<T>> Function() dashletValue;
  final String? route;
  final DashletWidgetBuilder<T>? widgetBuilder;
  final DashletWidgetBuilder<T>? builder;
  final VoidCallback? onTapOverride;
  final bool compact;

  @override
  State<DashletCard<T>> createState() => _DashletCardState<T>();
}

class _DashletCardState<T> extends State<DashletCard<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Choose sizes based on compact flag
    final maxW = widget.compact ? 140.0 : kDashletMaxWidth;
    final maxH = widget.compact ? 140.0 : kDashletMaxHeight;
    final minW = widget.compact ? 80.0 : 100.0;
    final minH = widget.compact ? 80.0 : 100.0;
    final iconSize = widget.compact ? 24.0 : 40.0;
    final labelStyle = widget.compact
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final valueStyle = widget.compact
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold);
    final spacing1 = widget.compact ? 4.0 : 8.0;
    final spacing2 = widget.compact ? 2.0 : 4.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxW,
        maxHeight: maxH,
        minWidth: minW,
        minHeight: minH,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTapOverride ?? () => unawaited(_handleTap(context)),
        child: Card(
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: Padding(
            padding: EdgeInsets.all(widget.compact ? 6 : 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  size: iconSize,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(height: spacing1),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                  maxLines: widget.compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacing2),
                JuneBuilder(
                  DashboardReloaded.new,
                  builder: (_) => FutureBuilderEx<DashletValue<T>>(
                    future: widget.dashletValue(),
                    builder: (ctx, dv) {
                      if (dv == null) {
                        return const SizedBox();
                      }
                      if (widget.widgetBuilder != null) {
                        return widget.widgetBuilder!(ctx, dv);
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dv.value.toString(),
                            style: valueStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dv.secondValue != null) ...[
                            SizedBox(height: spacing2),
                            Text(
                              dv.secondValue!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (widget.route != null) {
      await GoRouter.of(context).push(widget.route!);
    } else {
      final dv = await widget.dashletValue();
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (c) => (widget.builder ?? widget.widgetBuilder)!(c, dv),
          fullscreenDialog: true,
        ),
      );
    }
  }
}
