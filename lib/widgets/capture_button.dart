import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/capture_controller.dart';

/// The shutter button: a classic ring + inner disc with a press animation and
/// an in-progress spinner. Disabled while a capture is running to block double
/// taps. Reusable and self-contained — it reads/writes only [captureControllerProvider].
class CaptureButton extends ConsumerStatefulWidget {
  const CaptureButton({super.key});

  @override
  ConsumerState<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends ConsumerState<CaptureButton> {
  bool _pressed = false;

  Future<void> _onTap() async {
    HapticFeedback.mediumImpact();
    await ref.read(captureControllerProvider.notifier).capture();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(
      captureControllerProvider.select((s) => s.isBusy),
    );

    return GestureDetector(
      onTapDown: busy ? null : (_) => setState(() => _pressed = true),
      onTapUp: busy ? null : (_) => setState(() => _pressed = false),
      onTapCancel: busy ? null : () => setState(() => _pressed = false),
      onTap: busy ? null : _onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
