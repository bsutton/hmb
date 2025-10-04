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

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../util/flutter/hmb_theme.dart';
import '../layout/layout.g.dart';
import '../layout/surface.dart';
import 'hmb_droplist_multi_dialog.dart';

/// A multi-select dropdown list field with async loading,
/// built on DeferredState.
class HMBDroplistMultiSelect<T> extends StatefulWidget {
  /// Loads the currently selected items asynchronously.
  final Future<List<T>> Function() initialItems;

  /// Fetches the list of items, optionally filtered by filter.
  final Future<List<T>> Function(String? filter) items;

  /// Formats each item for display.
  final String Function(T) format;

  /// Called when the selection changes.
  final void Function(List<T>) onChanged;

  /// Title displayed above the field.
  final String title;

  /// Called when the form is saved (optional).
  final void Function(List<T>?)? onSaved;

  /// Background color of the field container.
  final Color? backgroundColor;

  /// Whether selection is required.
  final bool required;

  const HMBDroplistMultiSelect({
    required this.initialItems,
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    this.onSaved,
    this.backgroundColor,
    this.required = true,
    super.key,
  });

  /// A placeholder widget to show before items load.
  static Widget placeHolder() => const HMBPlaceHolder(height: 30);
  @override
  HMBDroplistMultiSelectState<T> createState() =>
      HMBDroplistMultiSelectState<T>();
}

class HMBDroplistMultiSelectState<T>
    extends DeferredState<HMBDroplistMultiSelect<T>> {
  List<T> _selectedItems = [];

  bool hasSelections() => _selectedItems.isNotEmpty;

  @override
  Future<void> asyncInitState() async {
    _selectedItems = await widget.initialItems();
  }

  void clear() {
    _selectedItems.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (context) => FormField<List<T>>(
      onSaved: widget.onSaved,
      initialValue: _selectedItems,
      autovalidateMode: AutovalidateMode.always,
      validator: (value) {
        if (widget.required && (value == null || value.isEmpty)) {
          return 'Please select at least one item';
        }
        return null;
      },
      builder: (state) => HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              final selected = await showDialog<List<T>>(
                context: context,
                builder: (_) => HMBDroplistMultiSelectDialog<T>(
                  getItems: widget.items,
                  formatItem: widget.format,
                  title: widget.title,
                  selectedItems: _selectedItems,
                ),
              );
              if (selected != null) {
                _selectedItems = selected;
                setState(() {});
                state.didChange(selected);
                widget.onChanged(selected);
              }
            },
            child: LabeledContainer(
              labelText: widget.title,
              backgroundColor:
                  widget.backgroundColor ?? SurfaceElevation.e4.color,
              isError: state.hasError,
              child: HMBRow(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _selectedItems.isNotEmpty
                          ? _selectedItems.map(widget.format).join('\n')
                          : 'Select ${widget.title}',
                      style: TextStyle(
                        fontSize: 13,
                        color: state.hasError
                            ? Theme.of(context).colorScheme.error
                            : HMBColors.textPrimary,
                      ),
                      softWrap: true, // allow wrapping
                      // overflow: TextOverflow.clip, // optional (default with softWrap)
                      // maxLines: null,              // unlimited lines (default)
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: HMBColors.dropboxArrow,
                  ),
                ],
              ),
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(
                state.errorText ?? '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
