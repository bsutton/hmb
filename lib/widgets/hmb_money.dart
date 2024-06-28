import 'package:flutter/material.dart';
import 'package:money2/money2.dart';

class HMBMoney extends StatelessWidget {
  const HMBMoney({
    required this.label, 
    required this.amount,
    super.key,
    this.leadingPadding = true,
  });
  final String label;
  final bool leadingPadding;
  final Money? amount;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (leadingPadding) const SizedBox(height: 8),
          Text(
            '$label $amount',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      );
}
