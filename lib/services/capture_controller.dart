import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/camera_controller.dart';
import '../filters/filter_repository.dart';
import '../filters/shader_manager.dart';
import 'image_capture_service.dart';

/// Where the capture flow currently is.
enum CapturePhase { idle, capturing, success, error }

@immutable
class CaptureState {
  const CaptureState({this.phase = CapturePhase.idle, this.errorMessage});

  final CapturePhase phase;
  final String? errorMessage;

  bool get isBusy => phase == CapturePhase.capturing;
}

/// Orchestrates the shutter: pulls the live controller, selected filter and
/// preloaded shaders together, runs [ImageCaptureService], and exposes a small
/// state machine the UI can react to (spinner, flash, snackbars).
class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  Future<void> capture() async {
    if (state.isBusy) return; // ignore double taps

    final controller = ref.read(cameraControllerProvider).value;
    final manager = ref.read(shaderManagerProvider).value;

    if (controller == null ||
        !controller.value.isInitialized ||
        manager == null) {
      state = const CaptureState(
        phase: CapturePhase.error,
        errorMessage: 'Camera is not ready yet.',
      );
      return;
    }

    state = const CaptureState(phase: CapturePhase.capturing);

    try {
      final filter = ref.read(selectedFilterProvider);
      final service = ImageCaptureService(shaderManager: manager);
      final bytes = await service.captureFiltered(
        controller: controller,
        filter: filter,
      );
      await service.saveToGallery(bytes);
      state = const CaptureState(phase: CapturePhase.success);
    } catch (error) {
      state = CaptureState(
        phase: CapturePhase.error,
        errorMessage: _messageFor(error),
      );
    }
  }

  /// Resets to idle after the UI has shown a result (snackbar/flash).
  void acknowledge() => state = const CaptureState();

  String _messageFor(Object error) {
    if (error is GalleryAccessDeniedException) {
      return 'Allow photo access to save your shot.';
    }
    return 'Could not capture the photo. Please try again.';
  }
}

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);
