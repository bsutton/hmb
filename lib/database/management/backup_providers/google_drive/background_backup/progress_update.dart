// --------------------
// Imports
// --------------------

class ProgressUpdate {
  ProgressUpdate(this.stageDescription, this.stageNo, this.stageCount);
  // A named constructor used for upload progress
  ProgressUpdate.upload(this.stageDescription) : stageNo = 6, stageCount = 7;
  final String stageDescription;
  final int stageNo;
  final int stageCount;
}
