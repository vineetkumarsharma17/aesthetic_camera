import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../filters/filtered_camera_preview.dart';
import '../services/capture_controller.dart';
import '../widgets/capture_button.dart';
import '../widgets/filter_carousel.dart';
import 'camera_controller.dart';

/// Root screen: full-screen filtered camera preview with a filter carousel and
/// shutter overlaid at the bottom.
///
/// The preview ([FilteredCameraPreview]) sits underneath a control layer so
/// that switching filters or capturing never rebuilds the [CameraPreview] and
/// the 60 FPS budget is preserved.
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(cameraControllerProvider.notifier).handleAppLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final cameraAsync = ref.watch(cameraControllerProvider);

    // Surface capture results as a snackbar + reset the state machine.
    ref.listen<CaptureState>(captureControllerProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.phase == CapturePhase.success) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Saved to gallery'),
              duration: Duration(seconds: 2),
            ),
          );
        ref.read(captureControllerProvider.notifier).acknowledge();
      } else if (next.phase == CapturePhase.error) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(next.errorMessage ?? 'Something went wrong'),
              duration: const Duration(seconds: 3),
            ),
          );
        ref.read(captureControllerProvider.notifier).acknowledge();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraAsync.when(
        data: (controller) => _CameraScene(controller: controller),
        loading: () => const _CameraLoading(),
        error: (error, _) => _CameraError(error: error),
      ),
    );
  }
}

/// The live scene: preview + bottom controls + a capture flash overlay.
class _CameraScene extends StatelessWidget {
  const _CameraScene({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _CameraPreviewLayer(controller: controller),
        const _BottomScrim(),
        const _CaptureFlash(),
        const SafeArea(
          child: Column(
            children: [
              Spacer(),
              FilterCarousel(),
              SizedBox(height: 12),
              CaptureButton(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fills the whole screen with the filtered preview (BoxFit.cover), cropping
/// the overflow so any sensor aspect ratio looks full-bleed.
class _CameraPreviewLayer extends StatelessWidget {
  const _CameraPreviewLayer({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            // aspectRatio is height/width in the preview's natural orientation.
            height: size.width * controller.value.aspectRatio,
            child: FilteredCameraPreview(controller: controller),
          ),
        ),
      ),
    );
  }
}

/// Subtle bottom gradient so white controls stay legible over bright scenes.
class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 260,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brief white flash when a photo is taken (fades out on its own).
class _CaptureFlash extends ConsumerStatefulWidget {
  const _CaptureFlash();

  @override
  ConsumerState<_CaptureFlash> createState() => _CaptureFlashState();
}

class _CaptureFlashState extends ConsumerState<_CaptureFlash> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<CaptureState>(captureControllerProvider, (previous, next) {
      if (next.phase == CapturePhase.capturing && mounted) {
        setState(() => _visible = true);
      }
    });

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: Duration(milliseconds: _visible ? 60 : 220),
        curve: Curves.easeOut,
        onEnd: () {
          // Once the flash-in completes, fade it back out.
          if (_visible && mounted) setState(() => _visible = false);
        },
        child: const ColoredBox(
          color: Colors.white,
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CameraLoading extends StatelessWidget {
  const _CameraLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}

/// Friendly error surface with a contextual action (retry or open settings).
class _CameraError extends ConsumerWidget {
  const _CameraError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPermissionIssue = error is CameraPermissionDeniedException;
    final isPermanentDenial = error is CameraPermissionDeniedException &&
        (error as CameraPermissionDeniedException).permanentlyDenied;

    final message = switch (error) {
      CameraPermissionDeniedException() =>
        'Camera access is needed to use Aesthetic Camera.',
      CameraException(:final description?) => description,
      _ => 'Something went wrong while starting the camera.',
    };

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              if (isPermanentDenial) {
                await openAppSettings();
              } else {
                await ref.read(cameraControllerProvider.notifier).retry();
              }
            },
            child: Text(
              isPermanentDenial
                  ? 'Open settings'
                  : isPermissionIssue
                      ? 'Grant access'
                      : 'Try again',
            ),
          ),
        ],
      ),
    );
  }
}
