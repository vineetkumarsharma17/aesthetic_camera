import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Raised when the user declines the camera permission prompt.
class CameraPermissionDeniedException implements Exception {
  const CameraPermissionDeniedException({this.permanentlyDenied = false});

  /// True when the OS will no longer show the prompt and the user must enable
  /// the permission from system settings.
  final bool permanentlyDenied;
}

/// Owns the [CameraController] lifecycle and exposes it as an [AsyncValue].
///
/// The controller is created lazily on first watch and disposed automatically
/// when the provider is destroyed. App background/foreground transitions are
/// funnelled through [handleAppLifecycle] so the native camera is released
/// while the app is not visible and rebuilt on resume.
class CameraControllerNotifier extends AsyncNotifier<CameraController> {
  CameraController? _controller;

  @override
  Future<CameraController> build() {
    ref.onDispose(_disposeController);
    return _initController();
  }

  Future<CameraController> _initController() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw CameraPermissionDeniedException(
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'No cameras available on this device.');
    }

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false, // stills only — no need for the mic permission
    );

    await controller.initialize();
    _controller = controller;
    return controller;
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  /// Releases the camera when the app is backgrounded and rebuilds it on resume.
  ///
  /// Native camera resources cannot be held while the app is not in the
  /// foreground, so we tear the controller down and recreate it rather than
  /// risk an invalid-state crash.
  Future<void> handleAppLifecycle(AppLifecycleState lifecycle) async {
    switch (lifecycle) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        await _disposeController();
      case AppLifecycleState.resumed:
        if (_controller == null) {
          state = const AsyncValue.loading();
          state = await AsyncValue.guard(_initController);
        }
    }
  }

  /// Retries initialization after a failure (e.g. the user granted permission
  /// in system settings and returned to the app).
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_initController);
  }
}

/// Single source of truth for the live [CameraController].
final cameraControllerProvider =
    AsyncNotifierProvider<CameraControllerNotifier, CameraController>(
  CameraControllerNotifier.new,
);
