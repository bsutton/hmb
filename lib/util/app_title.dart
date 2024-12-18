import 'package:june/june.dart';

class HMBTitle extends JuneState {
  String title = 'HMB';
}

void setAppTitle(String pageTitle) {
  /// Replace the top windows title with the current
  /// cruds title.
  /// We use a future as we are called during a build
  /// so can't call setState.
  Future.delayed(Duration.zero, () {
    final currentTitle = June.getState(HMBTitle.new);
    if (currentTitle.title != pageTitle) {
      June.getState(HMBTitle.new)
        ..title = pageTitle
        ..setState();
    }
  });
}
