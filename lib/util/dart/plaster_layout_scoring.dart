class PlasterLayoutScoring {
  final int extraSheetWeight;
  final int jointLengthWeight;
  final int cutPieceWeight;
  final int highJointWeight;
  final int smallPieceWeight;
  final int fragmentationWeight;

  const PlasterLayoutScoring({
    required this.extraSheetWeight,
    required this.jointLengthWeight,
    required this.cutPieceWeight,
    required this.highJointWeight,
    required this.smallPieceWeight,
    required this.fragmentationWeight,
  });

  const PlasterLayoutScoring.defaults()
    : extraSheetWeight = 1000000,
      jointLengthWeight = 1,
      cutPieceWeight = 2500,
      highJointWeight = 4,
      smallPieceWeight = 6000,
      fragmentationWeight = 1;
}
