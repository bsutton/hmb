// --------------------
// Imports
// --------------------

import 'dart:async';

/// Adds a tracker to [fileStream]
/// so that as data moves through the [fileStream]
/// we can call [onProgress] to report the progress
/// of the [fileStream] being read.
Stream<List<int>> trackProgress(
  Stream<List<int>> fileStream,
  int totalLength,
  void Function(double) onProgress,
) {
  var bytesUploaded = 0;
  return fileStream.transform(
    StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        bytesUploaded += data.length;
        final progress = (bytesUploaded / totalLength) * 100;
        onProgress(progress);
        sink.add(data);
      },
    ),
  );
}
