import 'dart:async';

import 'package:flutter/material.dart';

import 'hmb_droplist_dialog.dart';
import 'labeled_container.dart';

class HMBDroplist<T> extends FormField<T> {
  HMBDroplist({
    required Future<T?> Function()
        selectedItem, // Changed to a Future-returning function
    required Future<List<T>> Function(String? filter) items,
    required String Function(T) format,
    required void Function(T?) onChanged,
    required String title,
    super.onSaved,
    super.initialValue,
    bool required = true,
    super.key,
  }) : super(
          autovalidateMode: AutovalidateMode.always,
          builder: (state) => _HMBDroplist<T>(
            state: state,
            selectedItemFuture: selectedItem, // Pass the Future function
            items: items,
            format: format,
            onChanged: onChanged,
            title: title,
            required: required,
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
    required this.selectedItemFuture, // Accept the Future function
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    required this.required,
    super.key,
  });

  final FormFieldState<T> state;
  final Future<T?> Function() selectedItemFuture; // Future-returning function
  final Future<List<T>> Function(String? filter) items;
  final String Function(T) format;
  final void Function(T?) onChanged;
  final String title;
  final bool required;

  @override
  _HMBDroplistState<T> createState() => _HMBDroplistState<T>();
}

class _HMBDroplistState<T> extends State<_HMBDroplist<T>> {
  T? _selectedItem;
  bool _loading = true;

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
      widget.state.didChange(_selectedItem);
    // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      print('Error loading selected item: $e');
    }
  }

  @override
  void didUpdateWidget(covariant _HMBDroplist<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload selected item if the future function changes
    if (oldWidget.selectedItemFuture != widget.selectedItemFuture) {
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
                            : Theme.of(context).textTheme.bodyLarge?.color ??
                                Colors.black,
                      ),
                    ),
                  const Icon(Icons.arrow_drop_down),
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
