// lib/src/ui/dashboard/dashboard_base.dart

import 'package:flutter/material.dart';
import 'package:june/june.dart';

import '../../util/app_title.dart';
import 'dashlet_card.dart';
import 'route.dart';

/// Main dashboard page wired up to refresh on return
class DashboardPage extends StatefulWidget {
  const DashboardPage({required this.title, required this.dashlets, super.key});

  @override
  State<DashboardPage> createState() => DashboardState();

  final String title;
  final List<Widget> dashlets;
}

/// Base state class for any dashboard-like page that needs to refresh on return.
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

  /// Called when returning to this dashboard. Default refreshes and resets title.
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
        child: GridView.extent(
          maxCrossAxisExtent: kDashletMaxWidth,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          children: widget.dashlets,
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
