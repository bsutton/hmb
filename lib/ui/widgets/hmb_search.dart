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

import 'fields/hmb_text_field.dart';
import 'icons/hmb_add_button.dart';
import 'icons/hmb_clear_icon.dart';

/// I fyou need to be able to programatically clear the filter
/// then pass in a [HMBSearchController]
class HMBSearch extends StatefulWidget {
  final String label;

  final HMBSearchController? controller;

  final Future<void> Function(String? filter) onSearch;

  const HMBSearch({
    required this.onSearch,
    this.label = 'Search',
    super.key,
    this.controller,
  });

  @override
  State<StatefulWidget> createState() => HMBSearchState();
}

class HMBSearchState extends State<HMBSearch> {
  late final bool controllerOwned;
  late final HMBSearchController? filterController;

  String? filter;

  void clear() {
    filter = null;
    filterController?.clear();
  }

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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: HMBTextField(
          labelText: widget.label,
          controller: filterController!,
          onChanged: (newValue) async {
            filter = newValue;
            await widget.onSearch(filter);
          },
        ),
      ),
      HMBClearIcon(
        onPressed: () async {
          filterController?.clear();
          filter = null;
          await widget.onSearch(filter);
        },
      ),
    ],
  );
}

class HMBSearchWithAdd extends StatelessWidget {
  final void Function(String? filter) onSearch;

  final void Function() onAdd;
  final bool showAdd;

  final String? hint;

  final HMBSearchController? controller;

  /// The filter value returned via [onSearch] is
  /// trimmed and converted to lower case.
  const HMBSearchWithAdd({
    required this.onSearch,
    required this.onAdd,
    this.showAdd = true,
    this.controller,
    this.hint = 'Add',
    super.key,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: HMBSearch(
          onSearch: (filter) async {
            onSearch(filter?.trim().toLowerCase());
          },
          controller: controller,
        ),
      ),
      if (showAdd)
        HMBButtonAdd(onAdd: () async => onAdd(), enabled: true, hint: hint),
    ],
  );
}

class HMBSearchController extends TextEditingController {}
