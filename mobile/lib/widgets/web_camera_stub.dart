import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Stub implementation used on non-web platforms (Android, iOS).
/// All methods are no-ops. The native `camera` package is used instead.
class WebCameraController {
  bool get isReady => false;
  String? get error => 'Web camera not available on this platform';

  Future<void> initialize() async {}
  Future<Uint8List?> captureFrame() async => null;
  Future<List<Uint8List>> captureBurst(int count, Duration interval) async => [];
  void dispose() {}
}

class WebCameraView extends StatelessWidget {
  final WebCameraController controller;
  const WebCameraView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
