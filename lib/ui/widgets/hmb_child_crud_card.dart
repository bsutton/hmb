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


import 'package:flutter/material.dart';

import 'layout/layout.g.dart';

class HMBChildCrudCard extends StatelessWidget {
  final Widget crudListScreen;
  final String? headline;

  const HMBChildCrudCard({
    required this.crudListScreen,
    this.headline,
    super.key,
  });

  @override
  Widget build(BuildContext context) => HMBColumn(
    children: [
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.deepPurpleAccent,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: HMBColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headline != null)
                Text(
                  headline!,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              crudListScreen,
            ],
          ),
        ),
      ),
    ],
  );
}
