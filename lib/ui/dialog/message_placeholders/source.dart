import 'package:flutter/material.dart';

import '../source_context.dart';

abstract class Source<T> {
  Source({required this.name});
  String name;

  /// The source should call onChanged to notify
  /// providers that a new value exist.
  void onChanged(T? value, ResetFields resetFields) {
    _onChangeNotifier?.call(value, resetFields);
  }

  /// Used to notify the source holder that the source has changed.
  void Function(T? value, ResetFields resetFields)? _onChangeNotifier;

  // /// Used by the field picker to notify the ui
  // /// that a new value has been picked.
  // void Function(T? data, ResetFields resetFields)? onChanged;

  // ignore: avoid_setters_without_getters
  /// The template dialog calls listen to get change events
  /// from the source of the placeholder
  // ignore: use_setters_to_change_properties
  void listen(void Function(T? onChanged, ResetFields resetFields) onChanged) {
    _onChangeNotifier = onChanged;
  }

  Widget? widget();

  /// When a source calls onChanged with a new
  /// value the manager calls back with the
  /// current [SourceContext] giving the source
  /// a chance to revise the [SourceContext].
  /// This is called before the [ResetFields] settings
  /// is applied to other sources so that they
  /// will have the latest (revised) data
  void revise(SourceContext sourceContext);

  /// Called when a [Source] that this [Source] is
  /// dependant on changes.
  /// Also called to provide the initial value for
  /// the widget.
  void dependencyChanged(Source<dynamic> source, SourceContext sourceContext);

  T? get value;
}

class ResetFields {
  ResetFields({
    this.contact = false,
    this.customer = false,
    this.job = false,
    this.site = false,
  });
  bool contact;
  bool customer;
  bool job;
  bool site;
}
