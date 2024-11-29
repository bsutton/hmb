// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../ui/widgets/hmb_toast.dart';

class DesktopCameraDelegate extends ImagePickerCameraDelegate {
  List<CameraDescription> _cameras = [];
  int _cameraId = -1;
  bool _initialized = false;
  bool _isTakingPhoto = false;
  StreamSubscription<CameraErrorEvent>? _errorStreamSubscription;

  @override
  Future<XFile?> takePhoto(
      {ImagePickerCameraDelegateOptions options =
          const ImagePickerCameraDelegateOptions()}) async {
    if (_isTakingPhoto) {
      HMBToast.error('Camera is currently busy.');
      return null;
    }
    _isTakingPhoto = true;

    if (!_initialized) {
      await _initializeCamera();
    }

    try {
      // Capture the image
      final file = await CameraPlatform.instance.takePicture(_cameraId);
      return file;
    } catch (e) {
      HMBToast.error('Error capturing image: $e');
      return null;
    } finally {
      await _disposeCamera();
      _isTakingPhoto = false;
    }
  }

  Future<void> _fetchCameras() async {
    try {
      _cameras = await CameraPlatform.instance.availableCameras();
    } catch (e) {
      HMBToast.error('Error fetching cameras: $e');
    }
  }

  Future<void> _initializeCamera() async {
    print('initializeCamera');
    if (_cameras.isEmpty) {
      await _fetchCameras();
    }

    try {
      final camera = _cameras.first;
      _cameraId = await CameraPlatform.instance.createCameraWithSettings(
        camera,
        const MediaSettings(resolutionPreset: ResolutionPreset.high, fps: 30),
      );

      // Listen for camera initialization
      await CameraPlatform.instance.initializeCamera(_cameraId);
      _initialized = true;

      // Start monitoring the camera error stream
      _monitorCameraErrors();
    } catch (e) {
      HMBToast.error('Error initializing camera: $e');
      _initialized = false;
    }
  }

  void _monitorCameraErrors() {
    // Cancel any previous subscription to avoid duplicate listeners
    unawaited(_errorStreamSubscription?.cancel());

    _errorStreamSubscription =
        CameraPlatform.instance.onCameraError(_cameraId).listen((errorEvent) {
      HMBToast.error('Camera error detected: ${errorEvent.description}');
      unawaited(_resetCamera());
    });
  }

  Future<void> _resetCamera() async {
    await _disposeCamera();
    await _initializeCamera();
  }

  Future<void> _disposeCamera() async {
    // Dispose of error stream
    await _errorStreamSubscription?.cancel();
    _errorStreamSubscription = null;

    if (_initialized) {
      await CameraPlatform.instance.dispose(_cameraId);
      _initialized = false;
    }
  }

  @override
  Future<XFile?> takeVideo(
      {ImagePickerCameraDelegateOptions options =
          const ImagePickerCameraDelegateOptions()}) {
    throw UnimplementedError('Video capture is not yet supported on Windows.');
  }

  /// Initialize this CameraDelegate
  /// This method should be called before the ImagePicker is used
  /// on Windows.
  static void register() {
    final instance = ImagePickerPlatform.instance;
    if (instance is CameraDelegatingImagePickerPlatform) {
      instance.cameraDelegate = DesktopCameraDelegate();
    }
  }
}
