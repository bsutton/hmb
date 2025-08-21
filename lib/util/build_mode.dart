// ignore_for_file: do_not_use_environment

enum BuildMode { production, profile, debug }

BuildMode? _buildMode;

BuildMode get buildMode {
  if (_buildMode != null) {
    return _buildMode!;
  }

  if (const bool.fromEnvironment('dart.vm.product')) {
    _buildMode = BuildMode.production;
  } else if (const bool.fromEnvironment('dart.vm.profile')) {
    _buildMode = BuildMode.profile;
  } else {
    _buildMode = BuildMode.debug;
  }

  return _buildMode!;
}

bool get isDebugMode => buildMode == BuildMode.debug;
