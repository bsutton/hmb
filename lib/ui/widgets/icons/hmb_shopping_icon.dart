import 'package:flutter/material.dart';

import '../../../util/dart/types.dart';
import 'hmb_icon_button.dart';

class HMBShoppingIcon extends StatelessWidget {
  final AsyncVoidCallback onPressed;
  final String hint;
  final bool enabled;
  final bool small;

  const HMBShoppingIcon({
    required this.onPressed,
    this.small = false,
    super.key,
    this.hint = '''Move the item to the shopping list''',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => HMBIconButton(
    icon: const Icon(Icons.shopping_cart, size: 20, color: Colors.blue),
    size: small ? HMBIconButtonSize.small : HMBIconButtonSize.standard,
    showBackground: false,
    hint: hint,
    enabled: enabled,
    onPressed: onPressed,
  );
}
