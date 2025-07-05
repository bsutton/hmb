/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'dart:async';

import 'package:deferred_state/deferred_state.dart';
import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';
import '../layout/labeled_container.dart';
import '../surface.dart';
import 'hmb_droplist_dialog.dart';

/// A dropdown list field with async loading, built on DeferredState.
class HMBDroplist<T> extends StatefulWidget {
  const HMBDroplist({
    required this.selectedItem,
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    this.onAdd,
    this.backgroundColor,
    this.onSaved,
    this.initialValue,
    this.required = true,
    super.key,
  });

  final Future<T?> Function() selectedItem;
  final Future<List<T>> Function(String? filter) items;
  final String Function(T) format;
  final void Function(T?) onChanged;
  final String title;
  final Future<void> Function()? onAdd;
  final Color? backgroundColor;
  final void Function(T?)? onSaved;
  final T? initialValue;
  final bool required;

  @override
  HMBDroplistState<T> createState() => HMBDroplistState<T>();
}

class HMBDroplistState<T> extends DeferredState<HMBDroplist<T>> {
  T? _selectedItem;

  @override
  Future<void> asyncInitState() async {
    _selectedItem = widget.initialValue ?? await widget.selectedItem();
  }

  Future<void> _handleAdd() async {
    if (widget.onAdd != null) {
      await widget.onAdd!();
      _selectedItem = await widget.selectedItem();
      setState(() {});
    }
  }

  void clear() {
    _selectedItem = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => DeferredBuilder(
    this,
    builder: (aacontext) => FormField<T>(
      onSaved: widget.onSaved,
      initialValue: _selectedItem,
      autovalidateMode: AutovalidateMode.always,
      validator: (value) {
        if (widget.required && value == null) {
          return 'Please select an item';
        }
        return null;
      },
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              final selected = await showDialog<T>(
                context: context,
                builder: (_) => HMBDroplistDialog<T>(
                  getItems: widget.items,
                  formatItem: widget.format,
                  title: widget.title,
                  selectedItem: _selectedItem,
                  allowClear: !widget.required,
                  onAdd: widget.onAdd != null ? _handleAdd : null,
                ),
              );
              if (selected != null || !widget.required) {
                _selectedItem = selected;
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedItem != null
                        ? widget.format(_selectedItem as T)
                        : 'Select a ${widget.title}',
                    style: TextStyle(
                      fontSize: 16,
                      color: state.hasError
                          ? Theme.of(context).colorScheme.error
                          : HMBColors.textPrimary,
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
                style: const TextStyle(
                  color: HMBColors.errorBackground,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
