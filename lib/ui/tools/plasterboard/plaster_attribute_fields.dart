import 'package:flutter/material.dart';

import '../../../util/dart/plaster_board_attribute.dart';

class PlasterAttributeFields extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const PlasterAttributeFields({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Board attributes', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      for (final attribute in PlasterBoardAttribute.values)
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(attribute.label),
          value: value.hasPlasterBoardAttribute(attribute),
          onChanged: (selected) {
            final next = selected ?? false
                ? value | attribute.bit
                : value & ~attribute.bit;
            onChanged(next);
          },
        ),
    ],
  );
}
