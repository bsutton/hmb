class PlasterLayoutScoring {
  final int extraSheetWeight;
  final int jointLengthWeight;
  final int buttJointWeight;
  final int cutPieceWeight;
  final int highJointWeight;
  final int smallPieceWeight;
  final int fragmentationWeight;
  final int verticalWallPenaltyWeight;

  const PlasterLayoutScoring({
    required this.extraSheetWeight,
    required this.jointLengthWeight,
    required this.buttJointWeight,
    required this.cutPieceWeight,
    required this.highJointWeight,
    required this.smallPieceWeight,
    required this.fragmentationWeight,
    required this.verticalWallPenaltyWeight,
  });

  const PlasterLayoutScoring.defaults()
    : extraSheetWeight = 1000000,
      jointLengthWeight = 1,
      buttJointWeight = 40,
      cutPieceWeight = 2500,
      highJointWeight = 4,
      smallPieceWeight = 6000,
      fragmentationWeight = 1,
      verticalWallPenaltyWeight = 400000;
}
