import 'package:flutter/material.dart';

import 'fields/hmb_text_field.dart';
import 'hmb_add_button.dart';

/// I fyou need to be able to programatically clear the filter
/// then pass in a [HMBSearchController]
class HMBSearch extends StatefulWidget {
  const HMBSearch(
      {required this.onChanged,
      this.label = 'Search',
      super.key,
      this.controller});

  final Future<void> Function(String? filter) onChanged;

  final String label;

  final HMBSearchController? controller;

  @override
  State<StatefulWidget> createState() => HMBSearchState();
}

class HMBSearchState extends State<HMBSearch> {
  late final bool controllerOwned;
  late final HMBSearchController? filterController;

  String? filter;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      controllerOwned = true;
      filterController = widget.controller;
    } else {
      filterController = HMBSearchController();
      controllerOwned = false;
    }
  }

  @override
  void dispose() {
    if (controllerOwned) {
      filterController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: HMBTextField(
            leadingSpace: false,
            labelText: widget.label,
            controller: filterController!,
            onChanged: (newValue) async {
              filter = newValue;
              await widget.onChanged(filter);
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () async {
            filterController?.clear();
            filter = null;
            await widget.onChanged(filter);
          },
        )
      ]);
}

class HMBSearchWithAdd extends StatelessWidget {
  /// The filter value returned via [onSearch] is
  /// trimmed and converted to lower case.
  const HMBSearchWithAdd(
      {required this.onSearch,
      required this.onAdd,
      this.controller,
      super.key});

  final void Function(String? filter) onSearch;

  final void Function() onAdd;

  final HMBSearchController? controller;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: HMBSearch(
              onChanged: (filter) async {
                onSearch(filter?.trim().toLowerCase());
              },
              controller: controller,
            ),
          ),
          HMBButtonAdd(onPressed: () async => onAdd(), enabled: true),
        ],
      );
}

class HMBSearchController extends TextEditingController {}
