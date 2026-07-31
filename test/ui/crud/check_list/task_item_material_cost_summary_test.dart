@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/entity/material_price.dart';
import 'package:hmb/entity/task_item.dart';
import 'package:hmb/entity/task_item_type.dart';
import 'package:hmb/ui/crud/check_list/list_task_item_screen.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';

void main() {
  testWidgets('completed item shows actual cost below estimated cost', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _taskItem(
          completed: true,
          estimatedPrice: MaterialPrice.items(
            quantity: Fixed.fromNum(20, decimalDigits: 3),
            unitCost: MoneyEx.fromInt(125),
          ),
          actualPrice: MaterialPrice.items(
            quantity: Fixed.fromNum(18, decimalDigits: 3),
            unitCost: MoneyEx.fromInt(150),
          ),
        ),
      ),
    );

    final estimated = find.text(r'Est: Unit Cost: $1.25 Qty: 20');
    final actual = find.text(r'Actual: Unit Cost: $1.50 Qty: 18');
    expect(estimated, findsOneWidget);
    expect(actual, findsOneWidget);
    expect(
      tester.getTopLeft(actual).dy,
      greaterThan(tester.getTopLeft(estimated).dy),
    );
  });

  testWidgets('incomplete item does not show actual cost', (tester) async {
    await tester.pumpWidget(
      _app(
        _taskItem(
          completed: false,
          estimatedPrice: MaterialPrice.items(
            quantity: Fixed.one,
            unitCost: MoneyEx.dollars(10),
          ),
          actualPrice: MaterialPrice.items(
            quantity: Fixed.one,
            unitCost: MoneyEx.dollars(12),
          ),
        ),
      ),
    );

    expect(find.textContaining('Est:'), findsOneWidget);
    expect(find.textContaining('Actual:'), findsNothing);
  });

  testWidgets('completed package item retains package pricing labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _taskItem(
          completed: true,
          estimatedPrice: MaterialPrice.packages(
            packageCount: Fixed.fromNum(2, decimalDigits: 3),
            packageCost: MoneyEx.dollars(15),
            itemsPerPackage: Fixed.fromNum(10, decimalDigits: 3),
          ),
          actualPrice: MaterialPrice.packages(
            packageCount: Fixed.one,
            packageCost: MoneyEx.dollars(18),
            itemsPerPackage: Fixed.fromNum(10, decimalDigits: 3),
          ),
        ),
      ),
    );

    expect(find.text(r'Est: Package Cost: $15.00 Packages: 2'), findsOneWidget);
    expect(
      find.text(r'Actual: Package Cost: $18.00 Packages: 1'),
      findsOneWidget,
    );
  });
}

Widget _app(TaskItem taskItem) => MaterialApp(
  home: Scaffold(body: TaskItemMaterialCostSummary(taskItem: taskItem)),
);

TaskItem _taskItem({
  required bool completed,
  required MaterialPrice estimatedPrice,
  required MaterialPrice actualPrice,
}) => TaskItem.forInsert(
  taskId: 1,
  description: 'material',
  purpose: '',
  itemType: TaskItemType.materialsBuy,
  estimatedPrice: estimatedPrice,
  actualPrice: actualPrice,
  chargeMode: ChargeMode.calculated,
  margin: Percentage.zero,
  completed: completed,
  measurementType: MeasurementType.length,
  dimension1: Fixed.zero,
  dimension2: Fixed.zero,
  dimension3: Fixed.zero,
  units: Units.m,
  url: '',
  labourEntryMode: LabourEntryMode.hours,
);
