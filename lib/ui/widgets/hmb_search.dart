import 'package:flutter/material.dart';

import 'fields/hmb_text_field.dart';

class HMBSearch extends StatefulWidget {
  const HMBSearch({required this.onChanged, this.label = 'Search', super.key});

  final Future<void> Function(String? filter) onChanged;

  final String label;

  @override
  State<StatefulWidget> createState() => HMBSearchState();
}

class HMBSearchState extends State<HMBSearch> {
  late final TextEditingController filterController;

  String? filter;

  @override
  void initState() {
    super.initState();
    filterController = TextEditingController();
  }

  @override
  void dispose() {
    filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: HMBTextField(
            leadingSpace: false,
            labelText: widget.label,
            controller: filterController,
            onChanged: (newValue) async {
              filter = newValue;
              await widget.onChanged(filter);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () async {
            filterController.clear();
            filter = null;
            await widget.onChanged(filter);
          },
        )
      ]);
}
