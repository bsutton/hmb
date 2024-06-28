// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

class HMBChildCrudCard extends StatelessWidget {
  const HMBChildCrudCard({
    required this.crudListScreen,
    this.headline,
    super.key,
  });

  final Widget crudListScreen;
  final String? headline;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (headline != null)
                Text(
                  headline!,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: crudListScreen,
              ),
            ],
          ),
        ),
      );
}
