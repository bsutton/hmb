enum PlasterSheetDirection { auto, horizontal, vertical }

extension PlasterSheetDirectionX on PlasterSheetDirection {
  String get label => switch (this) {
    PlasterSheetDirection.auto => 'Auto',
    PlasterSheetDirection.horizontal => 'Horizontal',
    PlasterSheetDirection.vertical => 'Vertical',
  };

  String get layoutLabel => switch (this) {
    PlasterSheetDirection.auto => 'Auto',
    PlasterSheetDirection.horizontal => 'Horizontal lay',
    PlasterSheetDirection.vertical => 'Vertical lay',
  };

  String get storageValue => name;

  static PlasterSheetDirection fromStorage(String? raw) => switch (raw) {
    'horizontal' => PlasterSheetDirection.horizontal,
    'vertical' => PlasterSheetDirection.vertical,
    _ => PlasterSheetDirection.auto,
  };
}
