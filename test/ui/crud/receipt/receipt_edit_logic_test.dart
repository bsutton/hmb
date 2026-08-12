import 'package:hmb/ui/crud/receipt/receipt_edit_logic.dart';
import 'package:test/test.dart';

void main() {
  test('does not create an invalid allocation when a receipt has no job', () {
    expect(
      shouldCreateLegacyReceiptAllocation(
        hasPersistedAllocations: false,
        legacyJobId: null,
      ),
      isFalse,
    );
  });

  test('migrates a legacy receipt job into an allocation', () {
    expect(
      shouldCreateLegacyReceiptAllocation(
        hasPersistedAllocations: false,
        legacyJobId: 42,
      ),
      isTrue,
    );
  });

  test('keeps persisted allocations unchanged', () {
    expect(
      shouldCreateLegacyReceiptAllocation(
        hasPersistedAllocations: true,
        legacyJobId: 42,
      ),
      isFalse,
    );
  });

  test('moves a receipt line without losing its data', () {
    final lines = ['timber', 'paint', 'fixings'];

    moveReceiptLine(lines, 2, 1);

    expect(lines, ['timber', 'fixings', 'paint']);
  });

  test('ignores receipt line moves beyond either boundary', () {
    final lines = ['timber', 'paint'];

    moveReceiptLine(lines, 0, -1);
    moveReceiptLine(lines, 1, 2);

    expect(lines, ['timber', 'paint']);
  });
}
