class RoomEditorLine {
  final int id;
  final int seqNo;
  final int startX;
  final int startY;
  final int length;
  final bool plasterSelected;

  const RoomEditorLine({
    required this.id,
    required this.seqNo,
    required this.startX,
    required this.startY,
    required this.length,
    required this.plasterSelected,
  });

  RoomEditorLine copyWith({
    int? id,
    int? seqNo,
    int? startX,
    int? startY,
    int? length,
    bool? plasterSelected,
  }) => RoomEditorLine(
    id: id ?? this.id,
    seqNo: seqNo ?? this.seqNo,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    length: length ?? this.length,
    plasterSelected: plasterSelected ?? this.plasterSelected,
  );
}
