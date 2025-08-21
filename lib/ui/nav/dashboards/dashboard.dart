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

// lib/src/ui/dashboard/dashboard_base.dart

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../../util/app_title.dart';
import '../route.dart';

/// Main dashboard page wired up to refresh on return
class DashboardPage extends StatefulWidget {
  final String title;
  final List<Widget> dashlets;

  const DashboardPage({required this.title, required this.dashlets, super.key});

  @override
  State<DashboardPage> createState() => DashboardState();
}

/// Base state class for any dashboard-like page that needs to refresh
/// on return.
class DashboardState extends State<DashboardPage> with RouteAware {
  @override
  void initState() {
    super.initState();
    setAppTitle(widget.title);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Called when this route is exposed after a pop
    onDashboardResumed();
  }

  /// Called when returning to this dashboard. Default refreshes
  /// and resets title.
  @protected
  void onDashboardResumed() {
    setAppTitle(widget.title);
    June.getState<DashboardReloaded>(DashboardReloaded.new).setState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 16.0;
            const minTileWidth = 150.0; // Keep tiles to at lest 150
            final count =
                ((constraints.maxWidth + spacing) / (minTileWidth + spacing))
                    .floor()
                    .clamp(1, 6);

            return GridView.builder(
              itemCount: widget.dashlets.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemBuilder: (_, i) => widget.dashlets[i],
            );
          },
        ),
      ),
    ),
  );

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }
}

class DashboardReloaded extends JuneState {}
