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

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/dart/types.dart';
import '../../../util/flutter/hmb_theme.dart';
import '../layout/layout.g.dart';
import '../layout/surface.dart';
import 'hmb_droplist_dialog.dart';

/// A dropdown list field with async loading, built on DeferredState.
class HMBDroplist<T> extends StatefulWidget {
  final Future<T?> Function() selectedItem;
  final Future<List<T>> Function(String? filter) items;
  final String Function(T) format;
  final void Function(T?) onChanged;
  final String title;
  final AsyncVoidCallback? onAdd;
  final Color? backgroundColor;
  final void Function(T?)? onSaved;
  final Future<void> Function(T item)? onAccessed;
  final T? initialValue;
  final bool required;
  final bool showSearch;
  final Key? fieldKey;

  const HMBDroplist({
    required this.selectedItem,
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    this.onAdd,
    this.backgroundColor,
    this.onSaved,
    this.onAccessed,
    this.initialValue,
    this.required = true,
    this.showSearch = true,
    this.fieldKey,
    super.key,
  });

  @override
  HMBDroplistState<T> createState() => HMBDroplistState<T>();
}

class HMBDroplistState<T> extends DeferredState<HMBDroplist<T>> {
  T? _selectedItem;

  bool get hasSelection => _selectedItem != null;

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
  void didUpdateWidget(covariant HMBDroplist<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if the parent’s selectedItem() would now return something different...
    // ignore: discarded_futures
    widget.selectedItem().then((newSelection) {
      if (newSelection != _selectedItem) {
        if (mounted) {
          setState(() {
            _selectedItem = newSelection;
          });
        }
      }
    });
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
      builder: (state) => HMBColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: widget.fieldKey,
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
                  showSearch: widget.showSearch,
                ),
              );
              if (selected != null || !widget.required) {
                _selectedItem = selected;
                setState(() {});
                state.didChange(selected);
                if (selected != null) {
                  unawaited(_recordAccess(selected));
                }
                widget.onChanged(selected);
              }
            },
            child: LabeledContainer(
              labelText: widget.title,
              backgroundColor:
                  widget.backgroundColor ?? SurfaceElevation.e4.color,
              isError: state.hasError,
              child: HMBRow(
                children: [
                  Expanded(
                    child: Text(
                      _selectedItem != null
                          ? widget.format(_selectedItem as T)
                          : 'Select a ${widget.title}',
                      style: TextStyle(
                        fontSize: 16,
                        color: state.hasError
                            ? Theme.of(context).colorScheme.error
                            : HMBColors.textPrimary,
                      ),
                      maxLines: 1, // keep it to one line
                      overflow: TextOverflow.ellipsis, // show "…" if too long
                      softWrap: false, // prevent wrapping
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

  Future<void> _recordAccess(T item) async {
    final onAccessed = widget.onAccessed;
    if (onAccessed != null) {
      await onAccessed(item);
      return;
    }
    switch (item) {
      case final Supplier supplier:
        await DaoSupplier().recordAccess(supplier.id);
      case final Customer customer:
        await DaoCustomer().recordAccess(customer.id);
      case final Contact contact:
        await DaoContact().recordAccess(contact.id);
      case final Site site:
        await DaoSite().recordAccess(site.id);
      case final Manufacturer manufacturer:
        await DaoManufacturer().recordAccess(manufacturer.id);
      case final Category category:
        await DaoCategory().recordAccess(category.id);
      case final Task task:
        await DaoTask().recordAccess(task.id);
      case final Tool tool:
        await DaoTool().recordAccess(tool.id);
      case final MessageTemplate template:
        await DaoMessageTemplate().recordAccess(template.id);
    }
  }
}
