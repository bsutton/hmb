// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import 'layout/hmb_spacer.dart';

class HMBChildCrudCard extends StatelessWidget {
  const HMBChildCrudCard({
    required this.crudListScreen,
    this.headline,
    super.key,
  });

  final Widget crudListScreen;
  final String? headline;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const HMBSpacer(height: true),
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: Colors.deepPurpleAccent,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
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
