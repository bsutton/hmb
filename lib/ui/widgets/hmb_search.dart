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

import 'dart:async';

import 'package:material_ui/material_ui.dart';

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
  Timer? _debounceTimer;
  final _focusNode = FocusNode();

  String? filter;

  void clear() {
    filter = null;
    filterController?.clear();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);

    if (widget.controller != null) {
      controllerOwned = false;
      filterController = widget.controller;
    } else {
      filterController = HMBSearchController();
      controllerOwned = true;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.dispose();
    if (controllerOwned) {
      filterController?.dispose();
    }
    super.dispose();
  }

  void _focusChanged() {
    HMBSearchFocusNotification(focused: _focusNode.hasFocus).dispatch(context);
  }

  @override
  Widget build(BuildContext context) => HMBTextField(
    labelText: widget.label,
    focusNode: _focusNode,
    controller: filterController!,
    onChanged: (newValue) {
      filter = newValue;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        unawaited(widget.onSearch(filter));
      });
    },
    suffixIcon: HMBClearIcon(
      onPressed: () async {
        _debounceTimer?.cancel();
        filterController?.clear();
        filter = null;
        await widget.onSearch(filter);
      },
    ),
  );
}

class HMBSearchFocusNotification extends Notification {
  final bool focused;
  HMBSearchFocusNotification({required this.focused});
}

class HMBSearchWithAdd extends StatefulWidget {
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
  State<HMBSearchWithAdd> createState() => _HMBSearchWithAddState();
}

class _HMBSearchWithAddState extends State<HMBSearchWithAdd> {
  var _focused = false;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<HMBSearchFocusNotification>(
        onNotification: (notification) {
          setState(() => _focused = notification.focused);
          return false;
        },
        child: Row(
          children: [
            Expanded(
              child: HMBSearch(
                onSearch: (filter) async {
                  widget.onSearch(filter?.trim().toLowerCase());
                },
                controller: widget.controller,
              ),
            ),
            if (widget.showAdd && !_focused)
              HMBButtonAdd(
                onAdd: () async => widget.onAdd(),
                enabled: true,
                hint: widget.hint,
              ),
          ],
        ),
      );
}

class HMBSearchController extends TextEditingController {}
