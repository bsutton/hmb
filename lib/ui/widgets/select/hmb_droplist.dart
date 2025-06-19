import 'dart:async';

import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';
import '../layout/labeled_container.dart';
import '../surface.dart';
import 'hmb_droplist_dialog.dart';

class HMBDroplist<T> extends FormField<T> {
  HMBDroplist({
    required Future<T?> Function() selectedItem,
    required Future<List<T>> Function(String? filter) items,
    required String Function(T) format,
    required void Function(T?) onChanged,
    required String title,
    Future<void> Function()? onAdd, // Add a callback for the "Add" button
    Color? backgroundColor,
    super.onSaved,
    super.initialValue,
    bool required = true,
    super.key,
  }) : super(
         autovalidateMode: AutovalidateMode.always,
         builder: (state) => _HMBDroplist<T>(
           state: state,
           selectedItemFuture: selectedItem,
           items: items,
           format: format,
           onChanged: onChanged,
           title: title,
           backgroundColor: backgroundColor ?? SurfaceElevation.e4.color,
           required: required,
           onAdd: onAdd, // Pass the "Add" callback
         ),
         validator: (value) {
           if (required && value == null) {
             return 'Please select an item';
           }
           return null;
         },
       );
}

class _HMBDroplist<T> extends StatefulWidget {
  const _HMBDroplist({
    required this.state,
    required this.selectedItemFuture,
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    required this.backgroundColor,
    required this.required,
    this.onAdd, // Optional "Add" callback
    super.key,
  });

  final FormFieldState<T> state;
  final Future<T?> Function() selectedItemFuture;
  final Future<List<T>> Function(String? filter) items;
  final String Function(T) format;
  final void Function(T?) onChanged;
  final String title;
  final Color backgroundColor;
  final bool required;
  final Future<void> Function()? onAdd;

  @override
  _HMBDroplistState<T> createState() => _HMBDroplistState<T>();
}

class _HMBDroplistState<T> extends State<_HMBDroplist<T>> {
  T? _selectedItem;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSelectedItem());
  }

  Future<void> _loadSelectedItem() async {
    try {
      final selectedItem = await widget.selectedItemFuture();
      if (mounted) {
        setState(() {
          _selectedItem = selectedItem;
          _loading = false;
        });
      }
      if (mounted) {
        widget.state.didChange(_selectedItem);
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      print('Error loading selected item: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _HMBDroplist<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedItemFuture != widget.selectedItemFuture) {
      unawaited(_loadSelectedItem());
    }
  }

  Future<void> _handleAdd() async {
    if (widget.onAdd != null) {
      await widget.onAdd!();
      unawaited(_loadSelectedItem());
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final selectedItem = await showDialog<T>(
        context: context,
        builder: (context) => HMBDroplistDialog<T>(
          getItems: widget.items,
          formatItem: widget.format,
          title: widget.title,
          selectedItem: _selectedItem,
          allowClear: !widget.required,
          onAdd: widget.onAdd != null
              ? _handleAdd
              : null, // Pass the "Add" handler
        ),
      );

      if (selectedItem != null || !widget.required) {
        setState(() {
          _selectedItem = selectedItem;
        });
        widget.state.didChange(_selectedItem);
        widget.onChanged(_selectedItem);
      }
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledContainer(
          labelText: widget.title,
          backgroundColor: widget.backgroundColor,
          isError: widget.state.hasError,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_loading)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _selectedItem != null
                      ? widget.format(_selectedItem as T)
                      : 'Select a ${widget.title}',
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.state.hasError
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
              style: const TextStyle(
                color: HMBColors.errorBackground,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}
