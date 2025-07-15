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

typedef OnTap = void Function(BuildContext context);

/// A reusable dashlet card widget that reloads its data when the dashboard resumes.
/// Supports an optional compact mode for embedding in tighter UIs (e.g. job card).
/// A default valueBuilder is used to display the [value] unless
/// a [valueBuilder] is passed, in which case it is passed the [value]
/// and the resulting Widget is displayed.
class DashletCard<T> extends StatefulWidget {
  /// Create a [DashletCard] that when tapped navigates to a full screen
  /// containing the widget returned by [builder]
  const DashletCard.builder({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.builder,
    this.valueBuilder,
    this.compact = false,
    super.key,
  }) : route = null,
       onTap = null;

  /// Create a [DashletCard] that when tapped
  /// calls [onTap].
  const DashletCard.onTap({
    required this.label,
    required this.hint,
    required this.icon,
    required OnTap this.onTap,
    required this.value,
    this.valueBuilder,
    this.compact = false,
    super.key,
  }) : route = null,
       builder = null;

  /// Create a [DashletCard] that when tapped
  /// routes to [route]
  const DashletCard.route({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required String this.route,
    this.valueBuilder,
    this.compact = false,
    super.key,
  }) : builder = null,
       onTap = null;

  final String label;
  final String hint;
  final IconData icon;
  final Future<DashletValue<T>> Function() value;
  final DashletWidgetBuilder<T>? valueBuilder;
  final String? route;
  final DashletWidgetBuilder<T>? builder;
  final OnTap? onTap;
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
      child: Tooltip(
        message: widget.hint,
        triggerMode: TooltipTriggerMode.longPress,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => widget.onTap != null
              ? widget.onTap!(context)
              : unawaited(_handleTap(context)),
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
                      future: widget.value(),
                      builder: (ctx, dv) => widget.valueBuilder != null
                          ? widget.valueBuilder!(ctx, dv!)
                          : _buildDashletValue(dv, valueStyle, spacing2, theme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  RenderObjectWidget _buildDashletValue(
    DashletValue<dynamic>? dv,
    TextStyle? valueStyle,
    double spacing2,
    ThemeData theme,
  ) {
    if (dv == null) {
      return const SizedBox();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dv.value?.toString() ?? '',
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
  }

  Future<void> _handleTap(BuildContext context) async {
    if (widget.route != null) {
      await GoRouter.of(context).push(widget.route!);
      return;
    }

    {
      if (widget.onTap != null) {
        widget.onTap!(context);
        return;
      }
      if (widget.builder != null) {
        final dv = await widget.value();
        if (!context.mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (c) => widget.builder!(c, dv),
            fullscreenDialog: true,
          ),
        );
      }
    }
  }
}
