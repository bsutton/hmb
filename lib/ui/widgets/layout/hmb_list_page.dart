import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';
import '../text/hmb_text_themes.dart';
import '../widgets.g.dart';

class HMBListPage extends StatefulWidget {
  const HMBListPage({
    required this.emptyMessage,
    required this.itemCount,
    required this.itemBuilder,
    this.onSearch,
    this.onAdd,
    super.key,
  });

  @override
  State<HMBListPage> createState() => _HMBListPageState();

  final String emptyMessage;
  final NullableIndexedWidgetBuilder itemBuilder;
  final int itemCount;

  final void Function()? onAdd;
  final void Function(String? filter)? onSearch;
}

class _HMBListPageState extends State<HMBListPage> {
  @override
  Widget build(BuildContext context) {
    final child = (widget.itemCount == 0)
        ? Center(child: Text(widget.emptyMessage))
        : ListView.builder(
            itemCount: widget.itemCount,

            itemBuilder: widget.itemBuilder,
          );
    return Surface(
      elevation: SurfaceElevation.e0,
      child: Column(
        children: [
          if (widget.onSearch != null)
            Container(
              margin: HMBTheme.marginInset,
              child: HMBSearchWithAdd(
                onSearch: widget.onSearch!,
                showAdd: widget.onAdd != null,
                onAdd: widget.onAdd ?? () {},
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class HMBListCard extends StatelessWidget {
  const HMBListCard({
    required this.title,
    required this.children,
    this.actions,
    this.onTap,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final void Function()? onTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Surface(
      margin: const EdgeInsets.only(
        top: HMBTheme.margin,
        // bottom: HMBTheme.margin,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [HMBTextHeadline2(title), ...children],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [...?actions],
          ),
        ],
      ),
    ),
  );
}
