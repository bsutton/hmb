import 'package:flutter/material.dart';

typedef OnDelete = Future<void> Function();
typedef OnEdit = Widget Function();
typedef Allowed = bool Function();
typedef OnRefresh = Future<void> Function();

class HMBCrudListCard extends StatelessWidget {
  const HMBCrudListCard({
    required this.child,
    required this.title,
    required this.onDelete,
    required this.onEdit,
    required this.onRefresh,
    this.canEdit,
    this.canDelete,
    super.key,
  });

  final Widget child;
  final OnDelete onDelete;
  final OnEdit onEdit;
  final OnRefresh onRefresh;
  final Widget title;
  final Allowed? canEdit;
  final Allowed? canDelete;

  @override
  Widget build(BuildContext context) => GestureDetector(
    child: Card(
      semanticContainer: false,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: title),
                Visibility(
                  visible: canDelete?.call() ?? true,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    ),
    onTap: () => canEdit?.call() ?? true ? _pushEdit(context) : null,
  );

  Future<void> _pushEdit(BuildContext context) async {
    {
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (context) => onEdit()),
        ).then((_) => onRefresh());
      }
    }
  }
}
