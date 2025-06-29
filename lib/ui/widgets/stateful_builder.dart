/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License, with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:flutter/widgets.dart';

/// This is a duplicate of the Flutter [StatefulBuilder].
///
/// we have vendored the method as we need access to the [StatefulBuilderState]
/// which in the Flutter implementation is a private class.

/// A platonic widget that both has state and calls a closure to obtain its child widget.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=syvT63CosNE}
///
/// The [StateSetter] function passed to the [builder] is used to invoke a
/// rebuild instead of a typical [State]'s [State.setState].
///
/// Since the [builder] is re-invoked when the [StateSetter] is called, any
/// variables that represents state should be kept outside the [builder] function.
///
/// {@tool snippet}
///
/// This example shows using an inline StatefulBuilder that rebuilds and that
/// also has state.
///
/// ```dart
/// await showDialog<void>(
///   context: context,
///   builder: (BuildContext context) {
///     int? selectedRadio = 0;
///     return AlertDialog(
///       content: StatefulBuilder(
///         builder: (BuildContext context, StateSetter setState) {
///           return Column(
///             mainAxisSize: MainAxisSize.min,
///             children: List<Widget>.generate(4, (int index) {
///               return Radio<int>(
///                 value: index,
///                 groupValue: selectedRadio,
///                 onChanged: (int? value) {
///                   setState(() => selectedRadio = value);
///                 },
///               );
///             }),
///           );
///         },
///       ),
///     );
///   },
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [Builder], the platonic stateless widget.
class StatefulBuilder extends StatefulWidget {
  /// Creates a widget that both has state and delegates its build to a callback.
  const StatefulBuilder({required this.builder, super.key});

  /// Called to obtain the child widget.
  ///
  /// This function is called whenever this widget is included in its parent's
  /// build and the old widget (if any) that it synchronizes with has a distinct
  /// object identity. Typically the parent's build method will construct
  /// a new tree of widgets and so a new Builder child will not be [identical]
  /// to the corresponding old one.
  final StatefulWidgetBuilder builder;

  @override
  State<StatefulBuilder> createState() => StatefulBuilderState();
}

class StatefulBuilderState extends State<StatefulBuilder> {
  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
}
