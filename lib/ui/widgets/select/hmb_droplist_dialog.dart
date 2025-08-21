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

import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';
import '../color_ex.dart';
import '../hmb_icon_button.dart';
import '../surface.dart';

class HMBDroplistDialog<T> extends StatefulWidget {
  final Future<List<T>> Function(String? filter) getItems;
  final String Function(T) formatItem;
  final String title;
  final T? selectedItem;
  final bool allowClear;
  final Future<void> Function()? onAdd; // Optional "Add" button callback
  final bool showSearch;

  const HMBDroplistDialog({
    required this.getItems,
    required this.formatItem,
    required this.title,
    this.selectedItem,
    this.allowClear = false,
    this.onAdd, // Optional "Add" button callback
    super.key,
    this.showSearch = true,
  });

  @override
  // ignore: library_private_types_in_public_api
  _HMBDroplistDialogState<T> createState() => _HMBDroplistDialogState<T>();
}

class _HMBDroplistDialogState<T> extends State<HMBDroplistDialog<T>> {
  List<T>? _items;
  var _loading = true;
  var _filter = '';

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  Future<void> _handleAdd() async {
    if (widget.onAdd != null) {
      await widget.onAdd!();
      unawaited(_loadItems());
    }
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
                onPressed: () => Navigator.of(context).pop(widget.selectedItem),
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
            child: Surface(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _items!.length + (widget.allowClear ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (widget.allowClear && index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.clear, color: Colors.red),
                        title: const Text(
                          'Clear selection',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(),
                      );
                    }
                    final item = _items![index - (widget.allowClear ? 1 : 0)];
                    final isSelected = item == widget.selectedItem;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Theme.of(
                        context,
                      ).primaryColor.withSafeOpacity(0.1),
                      title: Text(
                        widget.formatItem(item),
                        style: const TextStyle(color: HMBColors.textPrimary),
                      ),
                      onTap: () {
                        Navigator.of(context).pop(item);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        if (widget.showSearch) _buildSearch(),
        const SizedBox(height: 16),
      ],
    ),
  );

  Surface _buildSearch() => Surface(
    elevation: SurfaceElevation.e6,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: HMBColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Search',
                labelStyle: const TextStyle(color: HMBColors.inputDecoration),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: HMBColors.inputDecoration,
                  ),
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
          if (widget.onAdd != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: HMBIconButton(
                onPressed: _handleAdd,
                icon: const Icon(Icons.add),
                hint: 'Add ${widget.title}',
              ),
            ),
        ],
      ),
    ),
  );
}
