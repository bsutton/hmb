// lib/src/ui/dashboard/dashboard_widgets.dart
import 'package:flutter/material.dart';
import 'package:future_builder_ex/future_builder_ex.dart';
import 'package:go_router/go_router.dart';

import '../../util/app_title.dart';

/// Holds primary and optional secondary values for a dashlet
class DashletValue<T> {
  const DashletValue(this.value, [this.secondValue]);
  final T value;
  final String? secondValue;
}

typedef DashletWidgetBuilder<T> =
    Widget Function(BuildContext context, DashletValue<T> dv);

/// A reusable dashlet card widget
class DashletCard<T> extends StatelessWidget {
  const DashletCard({
    required this.label,
    required this.icon,
    required this.future,
    super.key,
    this.route,
    this.widgetBuilder,
    this.builder,
    this.onTapOverride,
  });

  final String label;
  final IconData icon;
  final Future<DashletValue<T>> future;
  final String? route;
  final DashletWidgetBuilder<T>? widgetBuilder;
  final DashletWidgetBuilder<T>? builder;
  final VoidCallback? onTapOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTapOverride ?? () => _handleTap(context),
      child: Card(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilderEx<DashletValue<T>>(
              future: future,
              builder: (ctx, dv) {
                if (dv == null) {
                  return const SizedBox();
                }
                if (widgetBuilder != null) {
                  return widgetBuilder!(ctx, dv);
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
          ],
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (route != null) {
      await GoRouter.of(context).push(route!);
      setAppTitle('Dashboard');
    } else {
      final dv = await future;
      if (!context.mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (c) => (builder ?? widgetBuilder)!(c, dv),
          fullscreenDialog: true,
        ),
      );
      setAppTitle('Dashboard');
    }
  }
}
