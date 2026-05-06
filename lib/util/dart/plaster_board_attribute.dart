enum PlasterBoardAttribute {
  moistureMouldResistant(bit: 1 << 0, label: 'Moisture/mould resistant'),
  fireResistant(bit: 1 << 1, label: 'Fire resistant'),
  acoustic(bit: 1 << 2, label: 'Acoustic'),
  impactResistant(bit: 1 << 3, label: 'Impact resistant'),
  vapourControl(bit: 1 << 4, label: 'Vapour control');

  final int bit;
  final String label;

  const PlasterBoardAttribute({required this.bit, required this.label});
}

extension PlasterBoardAttributeMaskX on int {
  bool hasPlasterBoardAttribute(PlasterBoardAttribute attribute) =>
      this & attribute.bit == attribute.bit;

  bool includesPlasterBoardAttributes(int requiredMask) =>
      this & requiredMask == requiredMask;
}

String formatPlasterBoardAttributes(int mask) {
  final labels = [
    for (final attribute in PlasterBoardAttribute.values)
      if (mask.hasPlasterBoardAttribute(attribute)) attribute.label,
  ];
  return labels.isEmpty ? 'Standard' : labels.join(', ');
}
