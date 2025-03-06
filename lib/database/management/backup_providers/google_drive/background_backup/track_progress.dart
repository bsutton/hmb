// --------------------
// Imports
// --------------------

import 'dart:async';

Stream<List<int>> trackProgress(
  Stream<List<int>> source,
  int totalLength,
  void Function(double) onProgress,
) {
  var bytesUploaded = 0;
  return source.transform(
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
