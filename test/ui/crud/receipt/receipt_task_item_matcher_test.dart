import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/entity/helpers/charge_mode.dart';
import 'package:hmb/ui/crud/receipt/receipt_task_item_matcher.dart';
import 'package:hmb/util/dart/measurement_type.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:hmb/util/dart/units.dart';
import 'package:money2/money2.dart';
import 'package:test/test.dart';

void main() {
  test('sorts task items by likely receipt line match', () {
    final receiptDate = DateTime(2026, 5, 3);
    final likely = _taskItem(
      description: 'Premium unleaded petrol',
      unitCost: MoneyEx.dollars(80),
      modifiedDate: receiptDate,
      supplierId: 7,
    );
    final weaker = _taskItem(
      description: 'Timber screws',
      unitCost: MoneyEx.dollars(12),
      modifiedDate: receiptDate.subtract(const Duration(days: 20)),
      supplierId: 8,
    );

    final sorted = ReceiptTaskItemMatcher.sortForLine(
      [weaker, likely],
      ReceiptLineMatchInput(
        description: 'Petrol',
        lineTotalExTax: MoneyEx.dollars(80),
        receiptDate: receiptDate,
        supplierId: 7,
      ),
    );

    expect(sorted.first, likely);
  });

  test('ranks task items from near-term scheduled jobs first', () {
    final receiptDate = DateTime(2026, 5, 3);
    final scheduled = _taskItem(
      description: 'Generic materials',
      unitCost: MoneyEx.dollars(20),
      modifiedDate: receiptDate.subtract(const Duration(days: 10)),
      supplierId: 8,
    )..id = 11;
    final otherwiseLikely = _taskItem(
      description: 'Premium unleaded petrol',
      unitCost: MoneyEx.dollars(80),
      modifiedDate: receiptDate,
      supplierId: 7,
    )..id = 12;

    final sorted = ReceiptTaskItemMatcher.sortForLine(
      [otherwiseLikely, scheduled],
      ReceiptLineMatchInput(
        description: 'Petrol',
        lineTotalExTax: MoneyEx.dollars(80),
        receiptDate: receiptDate,
        supplierId: 7,
      ),
      preferredJobIds: {20},
      jobIdByTaskItemId: {11: 20, 12: 21},
    );

    expect(sorted.first, scheduled);
    expect(sorted, contains(otherwiseLikely));
  });

  test(
    'scores negative return receipt lines against positive return costs',
    () {
      final receiptDate = DateTime(2026, 5, 3);
      final returned = _taskItem(
        description: 'Returned timber',
        unitCost: MoneyEx.dollars(25),
        modifiedDate: receiptDate,
        supplierId: 7,
        isReturn: true,
      );
      final other = _taskItem(
        description: 'Petrol',
        unitCost: MoneyEx.dollars(80),
        modifiedDate: receiptDate,
        supplierId: 7,
      );

      final sorted = ReceiptTaskItemMatcher.sortForLine(
        [other, returned],
        ReceiptLineMatchInput(
          description: 'Timber return',
          lineTotalExTax: MoneyEx.fromInt(-2500),
          receiptDate: receiptDate,
          supplierId: 7,
        ),
      );

      expect(sorted.first, returned);
    },
  );

  test('receipt pricing preserves package details and overwrites total', () {
    final item =
        _taskItem(
          description: 'Boxed screws',
          unitCost: MoneyEx.dollars(10),
          modifiedDate: DateTime(2026, 5, 3),
          supplierId: 7,
        ).copyWith(
          estimatedPrice: MaterialPrice.packages(
            packageCount: Fixed.fromNum(2, decimalDigits: 3),
            packageCost: MoneyEx.dollars(10),
            itemsPerPackage: Fixed.fromNum(50, decimalDigits: 3),
          ),
          clearActualPrice: true,
        );

    final actual = ReceiptTaskItemMatcher.actualPriceForLine(
      item: item,
      lineTotalExTax: MoneyEx.dollars(30),
      fallbackQuantity: Fixed.one,
    );

    expect(actual.mode, MaterialPriceEntryMode.packages);
    expect(actual.quantity, Fixed.fromNum(2, decimalDigits: 3));
    expect(actual.itemsPerPackage, Fixed.fromNum(50, decimalDigits: 3));
    expect(actual.unitCost, MoneyEx.dollars(15));
    expect(actual.totalCost, MoneyEx.dollars(30));
  });
}

TaskItem _taskItem({
  required String description,
  required Money unitCost,
  required DateTime modifiedDate,
  required int supplierId,
  bool isReturn = false,
}) {
  final item = TaskItem.forInsert(
    taskId: 1,
    description: description,
    purpose: '',
    itemType: TaskItemType.materialsBuy,
    estimatedPrice: MaterialPrice.items(
      quantity: Fixed.one,
      unitCost: unitCost,
    ),
    actualPrice: MaterialPrice.items(quantity: Fixed.one, unitCost: unitCost),
    chargeMode: ChargeMode.calculated,
    margin: Percentage.zero,
    completed: true,
    measurementType: MeasurementType.length,
    dimension1: Fixed.zero,
    dimension2: Fixed.zero,
    dimension3: Fixed.zero,
    units: Units.m,
    url: '',
    labourEntryMode: LabourEntryMode.hours,
    supplierId: supplierId,
    isReturn: isReturn,
  )..modifiedDate = modifiedDate;
  return item;
}
