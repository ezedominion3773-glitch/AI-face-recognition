import 'dart:async';
import 'package:camera/camera.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;

  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool isInitialized = false;

  CameraService._internal();

  Future<bool> initialize() async {
    if (isInitialized) return true;
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("Error: No cameras available");
        return false;
      }

      // Select front camera if available, otherwise first camera
      CameraDescription? frontCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      final selectedCamera = frontCamera ?? cameras.first;

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();
      isInitialized = true;
      return true;
    } catch (e) {
      print("Error initializing camera: $e");
      isInitialized = false;
      return false;
    }
  }

  Future<XFile?> captureSingleFrame() async {
    if (controller == null || !controller!.value.isInitialized) {
      return null;
    }
    try {
      return await controller!.takePicture();
    } catch (e) {
      print("Error taking picture: $e");
      return null;
    }
  }

  Future<List<List<int>>> captureBurst(int count, Duration interval) async {
    List<List<int>> burst = [];
    if (controller == null || !controller!.value.isInitialized) {
      return burst;
    }

    for (int i = 0; i < count; i++) {
      try {
        final file = await controller!.takePicture();
        final bytes = await file.readAsBytes();
        burst.add(bytes);
      } catch (e) {
        print("Error during burst capture: $e");
      }
      await Future.delayed(interval);
    }

    return burst;
  }

  void dispose() {
    controller?.dispose();
    controller = null;
    isInitialized = false;
  }
}
