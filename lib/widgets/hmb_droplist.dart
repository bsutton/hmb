import 'dart:async';

import 'package:flutter/material.dart';

import 'hmb_droplist_dialog.dart';
import 'hmb_placeholder.dart';
import 'labeled_container.dart';

class HMBDroplist<T> extends FormField<T> {
  HMBDroplist({
    required Future<T?> Function() initialItem,
    required Future<List<T>> Function(String? filter) items,
    required String Function(T) format,
    required void Function(T) onChanged,
    required String title,
    super.onSaved,
    super.initialValue,
    bool required = true,
    super.key,
  }) : super(
          autovalidateMode: AutovalidateMode.always,
          builder: (state) => _HMBDroplist<T>(
            key: ValueKey(initialItem),
            state: state,
            initialItem: initialItem,
            items: items,
            format: format,
            onChanged: onChanged,
            title: title,
          ),
          validator: (value) {
            if (required && value == null) {
              return 'Please select an item';
            }
            return null;
          },
        );

  static Widget placeHolder() => const HMBPlaceHolder(height: 30);
}

class _HMBDroplist<T> extends StatefulWidget {
  const _HMBDroplist({
    required this.state,
    required this.initialItem,
    required this.items,
    required this.format,
    required this.onChanged,
    required this.title,
    required super.key,
  });

  final FormFieldState<T> state;
  final Future<T?> Function() initialItem;
  final Future<List<T>> Function(String? filter) items;
  final String Function(T) format;
  final void Function(T) onChanged;
  final String title;

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
      _selectedItem = await widget.initialItem();
      if (mounted) {
        setState(() {
          print('Loading completed: _selectedItem = $_selectedItem');
          _loading = false;
        });
      }
      widget.state.didChange(_selectedItem);
    } catch (e) {
      print('Error loading item: $e');
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
            ),
          );

          if (selectedItem != null) {
            if (mounted) {
              setState(() {
                print('Item selected: _selectedItem = $selectedItem');
                _selectedItem = selectedItem;
              });
            }
            widget.state.didChange(selectedItem);
            widget.onChanged(selectedItem);
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
                    const CircularProgressIndicator()
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
