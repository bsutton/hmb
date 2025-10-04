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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import '../hmb_delete_icon.dart';
import '../hmb_edit_icon.dart';
import 'layout.g.dart';

typedef OnDelete = AsyncVoidCallback;
typedef OnEdit = Widget Function();
typedef Allowed = bool Function();
typedef OnRefresh = AsyncVoidCallback;

class HMBCrudListCard extends StatelessWidget {
  final Widget child;
  final OnDelete onDelete;
  final OnEdit onEdit;
  final OnRefresh onRefresh;
  final Widget title;
  final Allowed? canEdit;
  final Allowed? canDelete;

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

  @override
  Widget build(BuildContext context) =>
      // GestureDetector(
      // child:
      Card(
        semanticContainer: false,
        elevation: 2,
        child: HMBColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: title),
                  HMBEditIcon(
                    onPressed: () async => canEdit?.call() ?? true
                        ? unawaited(_pushEdit(context))
                        : null,
                    hint: 'Edit',
                  ),
                  Visibility(
                    visible: canDelete?.call() ?? true,
                    child: HMBDeleteIcon(onPressed: onDelete),
                  ),
                ],
              ),
            ),
            child,
          ],
        ),
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
