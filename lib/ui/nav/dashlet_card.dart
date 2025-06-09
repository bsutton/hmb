// lib/src/ui/dashboard/dashlet_card.dart

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

/// A reusable dashlet card widget that reloads its data when the dashboard resumes
class DashletCard<T> extends StatefulWidget {
  const DashletCard({
    required this.label,
    required this.icon,
    required this.dashletValue,
    super.key,
    this.route,
    this.widgetBuilder,
    this.builder,
    this.onTapOverride,
  });

  final String label;
  final IconData icon;
  final Future<DashletValue<T>> Function() dashletValue;
  final String? route;
  final DashletWidgetBuilder<T>? widgetBuilder;
  final DashletWidgetBuilder<T>? builder;
  final VoidCallback? onTapOverride;

  @override
  State<DashletCard<T>> createState() => _DashletCardState<T>();
}

class _DashletCardState<T> extends State<DashletCard<T>> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: kDashletMaxWidth,
        maxHeight: kDashletMaxHeight,
        minHeight: 100,
        minWidth: 100,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              JuneBuilder(
                DashboardReloaded.new,
                builder: (_) => FutureBuilderEx<DashletValue<T>>(
                  // ignore: discarded_futures
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (dv.secondValue != null) ...[
                          const SizedBox(height: 2),
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
