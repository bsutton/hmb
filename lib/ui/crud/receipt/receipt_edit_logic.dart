bool shouldCreateLegacyReceiptAllocation({
  required bool hasPersistedAllocations,
  required int? legacyJobId,
}) => !hasPersistedAllocations && legacyJobId != null;

void moveReceiptLine<T>(List<T> lines, int fromIndex, int toIndex) {
  if (fromIndex == toIndex ||
      fromIndex < 0 ||
      fromIndex >= lines.length ||
      toIndex < 0 ||
      toIndex >= lines.length) {
    return;
  }
  lines.insert(toIndex, lines.removeAt(fromIndex));
}
