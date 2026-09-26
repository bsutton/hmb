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

import 'package:flutter/widgets.dart';

import 'hmb_column.dart';
import 'hmb_spacing.dart';

/// A group of related form fields. The parent owns the gap between sections.
class HMBFormSection extends HMBColumn {
  const HMBFormSection({
    required super.children,
    super.key,
    super.leadingSpace = false,
    super.mainAxisSize = MainAxisSize.min,
    super.mainAxisAlignment,
    super.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.spacing = HMBSpacing.kFieldGap,
  });
}

/// A scrolling form with page insets and consistent gaps between its children.
/// Children should not add their own vertical spacers or outside margins.
class HMBFormList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final ScrollController? controller;

  const HMBFormList({
    required this.children,
    this.padding = const EdgeInsets.all(HMBSpacing.kPageInset),
    this.spacing = HMBSpacing.kFieldGap,
    this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    controller: controller,
    padding: padding,
    itemCount: children.length,
    itemBuilder: (_, index) => children[index],
    separatorBuilder: (_, _) => SizedBox(height: spacing),
  );
}
