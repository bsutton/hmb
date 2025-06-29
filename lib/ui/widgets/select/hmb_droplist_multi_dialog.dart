/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:flutter/material.dart';

import '../color_ex.dart';
import '../hmb_button.dart';

class HMBDroplistMultiSelectDialog<T> extends StatefulWidget {
  const HMBDroplistMultiSelectDialog({
    required this.getItems,
    required this.formatItem,
    required this.title,
    required this.selectedItems,
    super.key,
  });

  final Future<List<T>> Function(String? filter) getItems;
  final String Function(T) formatItem;
  final String title;
  final List<T> selectedItems;

  @override
  // ignore: library_private_types_in_public_api
  _HMBDroplistMultiSelectDialogState<T> createState() =>
      _HMBDroplistMultiSelectDialogState<T>();
}

class _HMBDroplistMultiSelectDialogState<T>
    extends State<HMBDroplistMultiSelectDialog<T>> {
  List<T>? _items;
  var _loading = true;
  var _filter = '';
  late List<T> _selectedItems;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.selectedItems);
    unawaited(_loadItems());
  }

  Future<void> _loadItems() async {
    _items = await widget.getItems(_filter);
    setState(() {
      _loading = false;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _filter = filter;
      _loading = true;
    });
    unawaited(_loadItems());
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(_selectedItems),
              ),
            ],
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          )
        else if (_items != null)
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items!.length,
                itemBuilder: (context, index) {
                  final item = _items![index];
                  final isSelected = _selectedItems.contains(item);
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Theme.of(
                      context,
                    ).primaryColor.withSafeOpacity(0.1),
                    title: Text(widget.formatItem(item)),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedItems.remove(item);
                        } else {
                          _selectedItems.add(item);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _searchController.text = '';
                    _filter = '';
                    _loading = true;
                  });
                  unawaited(_loadItems());
                },
              ),
            ),
            onChanged: _onFilterChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: HMBButton(
            hint: 'Close the selection window with your selections',
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(_selectedItems),
          ),
        ),
      ],
    ),
  );
}
