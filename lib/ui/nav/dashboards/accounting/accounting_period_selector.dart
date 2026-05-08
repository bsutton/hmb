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

import 'package:flutter/material.dart';

import '../../../../dao/accounting_report_service.dart';
import '../../../../util/dart/format.dart';
import '../../../widgets/layout/layout.g.dart';
import '../../../widgets/layout/surface.dart';

enum AccountingPeriodPreset { month, quarter, year, financialYear, custom }

class AccountingPeriodSelector extends StatefulWidget {
  final AccountingPeriod initialPeriod;
  final ValueChanged<AccountingPeriod> onChanged;

  const AccountingPeriodSelector({
    required this.initialPeriod,
    required this.onChanged,
    super.key,
  });

  @override
  State<AccountingPeriodSelector> createState() =>
      _AccountingPeriodSelectorState();
}

class _AccountingPeriodSelectorState extends State<AccountingPeriodSelector> {
  var _preset = AccountingPeriodPreset.month;
  late DateTime _anchor;
  late AccountingPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;
    _anchor = _period.startInclusive;
  }

  @override
  Widget build(BuildContext context) => Surface(
    child: HMBColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<AccountingPeriodPreset>(
              value: _preset,
              items: [
                for (final preset in AccountingPeriodPreset.values)
                  DropdownMenuItem(
                    value: preset,
                    child: Text(_presetLabel(preset)),
                  ),
              ],
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                _preset = value;
                await _setPeriodForAnchor();
              },
            ),
            IconButton(
              tooltip: 'Previous period',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _move(-1),
            ),
            Text(_periodLabel(_period)),
            IconButton(
              tooltip: 'Next period',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _move(1),
            ),
          ],
        ),
        if (_preset == AccountingPeriodPreset.custom)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(formatDate(_period.startInclusive)),
                onPressed: () => _pickStart(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(formatDate(_period.endExclusive)),
                onPressed: () => _pickEnd(context),
              ),
            ],
          ),
      ],
    ),
  );

  Future<void> _move(int direction) async {
    _anchor = switch (_preset) {
      AccountingPeriodPreset.month => DateTime(
        _anchor.year,
        _anchor.month + direction,
      ),
      AccountingPeriodPreset.quarter => DateTime(
        _anchor.year,
        _anchor.month + (direction * 3),
      ),
      AccountingPeriodPreset.year || AccountingPeriodPreset.financialYear =>
        DateTime(_anchor.year + direction, _anchor.month),
      AccountingPeriodPreset.custom => _anchor.add(Duration(days: direction)),
    };
    await _setPeriodForAnchor();
  }

  Future<void> _setPeriodForAnchor() async {
    final next = switch (_preset) {
      AccountingPeriodPreset.month => AccountingPeriod.forMonth(_anchor),
      AccountingPeriodPreset.quarter => AccountingPeriod.forQuarter(_anchor),
      AccountingPeriodPreset.year => AccountingPeriod.forYear(_anchor),
      AccountingPeriodPreset.financialYear =>
        await AccountingPeriod.forFinancialYear(_anchor),
      AccountingPeriodPreset.custom => _period,
    };
    _setPeriod(next);
  }

  Future<void> _pickStart(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _period.startInclusive,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    _setPeriod(
      AccountingPeriod(
        startInclusive: selected,
        endExclusive: _period.endExclusive.isAfter(selected)
            ? _period.endExclusive
            : selected.add(const Duration(days: 1)),
      ),
    );
  }

  Future<void> _pickEnd(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _period.endExclusive.subtract(const Duration(days: 1)),
      firstDate: _period.startInclusive,
      lastDate: DateTime(2100),
    );
    if (selected == null) {
      return;
    }
    _setPeriod(
      AccountingPeriod(
        startInclusive: _period.startInclusive,
        endExclusive: selected.add(const Duration(days: 1)),
      ),
    );
  }

  void _setPeriod(AccountingPeriod period) {
    setState(() {
      _period = period;
      _anchor = period.startInclusive;
    });
    widget.onChanged(period);
  }

  String _presetLabel(AccountingPeriodPreset preset) => switch (preset) {
    AccountingPeriodPreset.month => 'Month',
    AccountingPeriodPreset.quarter => 'Quarter',
    AccountingPeriodPreset.year => 'Calendar year',
    AccountingPeriodPreset.financialYear => 'Financial year',
    AccountingPeriodPreset.custom => 'Custom',
  };

  String _periodLabel(AccountingPeriod period) =>
      '${formatDate(period.startInclusive)} to '
      '${formatDate(period.endExclusive.subtract(const Duration(days: 1)))}';
}
