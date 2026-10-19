import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The front camera used for the live selfie check (screen 16).
abstract interface class SelfieCamera {
  Future<void> open();
  Widget preview();
  Future<String> capture(); // path to a JPEG
  Future<void> close();
}

class DeviceSelfieCamera implements SelfieCamera {
  CameraController? _controller;

  @override
  Future<void> open() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    // Medium keeps uploads well under the server's 5 MB limit.
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    _controller = controller;
  }

  @override
  Widget preview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return const SizedBox.expand();
    // Fill the oval: cover-crop the preview, which reports landscape size.
    final size = controller.value.previewSize!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: size.height, height: size.width, child: CameraPreview(controller)),
    );
  }

  @override
  Future<String> capture() async => (await _controller!.takePicture()).path;

  @override
  Future<void> close() async {
    await _controller?.dispose();
    _controller = null;
  }
}

final selfieCameraProvider = Provider.autoDispose<SelfieCamera>((ref) => DeviceSelfieCamera());
