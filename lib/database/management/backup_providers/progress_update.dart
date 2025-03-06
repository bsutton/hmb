class ProgressUpdate {
  ProgressUpdate(this.stageDescription, this.stageNo, this.stageCount);

  ProgressUpdate.upload(this.stageDescription) : stageNo = 6, stageCount = 7;

  final String stageDescription;
  final int stageNo;
  final int stageCount;
}
