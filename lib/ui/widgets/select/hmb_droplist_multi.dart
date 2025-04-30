import 'dart:async';

import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';
import '../layout/hmb_placeholder.dart';
import '../layout/labeled_container.dart';
import '../surface.dart';
import 'hmb_droplist_multi_dialog.dart';

class HMBDroplistMultiSelect<T> extends FormField<List<T>> {
  HMBDroplistMultiSelect({
    required Future<List<T>> Function() initialItems,
    required Future<List<T>> Function(String? filter) items,
    required String Function(T) format,
    required void Function(List<T>) onChanged,
    required String title,
    Color? backgroundColor,
    super.onSaved,
    super.initialValue,
    bool required = true,
    super.key,
  }) : super(
         autovalidateMode: AutovalidateMode.always,
         builder:
             (state) => _HMBDroplistMultiSelect<T>(
               key: ValueKey(initialItems),
               state: state,
               initialItems: initialItems,
               items: items,
               format: format,
               onChanged: onChanged,
               title: title,
               backgroundColor: backgroundColor ?? SurfaceElevation.e4.color,
             ),
         validator: (value) {
           if (required && (value == null || value.isEmpty)) {
             return 'Please select at least one item';
           }
           return null;
         },
       );

  static Widget placeHolder() => const HMBPlaceHolder(height: 30);
}

class _HMBDroplistMultiSelect<T> extends StatefulWidget {
  const _HMBDroplistMultiSelect({
    required this.state,
    required this.initialItems,
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    required super.key,
    required this.backgroundColor,
  });

  final FormFieldState<List<T>> state;
  final Future<List<T>> Function() initialItems;
  final Future<List<T>> Function(String? filter) items;
  final String Function(T) format;
  final void Function(List<T>) onChanged;
  final String title;
  final Color backgroundColor;

  @override
  _HMBDroplistMultiSelectState<T> createState() =>
      _HMBDroplistMultiSelectState<T>();
}

class _HMBDroplistMultiSelectState<T>
    extends State<_HMBDroplistMultiSelect<T>> {
  List<T> _selectedItems = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSelectedItems());
  }

  Future<void> _loadSelectedItems() async {
    try {
      _selectedItems = await widget.initialItems();
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      widget.state.didChange(_selectedItems);
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      print('Error loading items: $e');
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final selectedItems = await showDialog<List<T>>(
        context: context,
        builder:
            (context) => HMBDroplistMultiSelectDialog<T>(
              getItems: widget.items,
              formatItem: widget.format,
              title: widget.title,
              selectedItems: _selectedItems,
            ),
      );

      if (selectedItems != null) {
        if (mounted) {
          setState(() {
            _selectedItems = selectedItems;
          });
        }
        widget.state.didChange(selectedItems);
        widget.onChanged(selectedItems);
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledContainer(
          labelText: widget.title,
          isError: widget.state.hasError,
          backgroundColor: widget.backgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else
                Text(
                  _selectedItems.isNotEmpty
                      ? _selectedItems.map(widget.format).join(', ')
                      : 'Select ${widget.title}',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        widget.state.hasError
                            ? Theme.of(context).colorScheme.error
                            : HMBColors.textPrimary,
                  ),
                ),
              const Icon(Icons.arrow_drop_down, color: HMBColors.dropboxArrow),
            ],
          ),
        ),
        if (widget.state.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 8),
            child: Text(
              widget.state.errorText ?? '',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}
