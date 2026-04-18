class RoomEditorLine {
  final int id;
  final int seqNo;
  final int startX;
  final int startY;
  final int length;

  const RoomEditorLine({
    required this.id,
    required this.seqNo,
    required this.startX,
    required this.startY,
    required this.length,
  });

  RoomEditorLine copyWith({
    int? id,
    int? seqNo,
    int? startX,
    int? startY,
    int? length,
  }) => RoomEditorLine(
    id: id ?? this.id,
    seqNo: seqNo ?? this.seqNo,
    startX: startX ?? this.startX,
    startY: startY ?? this.startY,
    length: length ?? this.length,
  );
}
