import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Real web camera implementation using the browser's getUserMedia API.
/// Only compiled when running on Web (selected via conditional import).
class WebCameraController {
  html.VideoElement? _videoElement;
  html.CanvasElement? _canvasElement;
  bool _isReady = false;
  String? _viewType;
  String? _error;

  bool get isReady => _isReady;
  String? get error => _error;
  String? get viewType => _viewType;

  Future<void> initialize() async {
    _viewType = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';

    _videoElement = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'; // Mirror for selfie view

    _canvasElement = html.CanvasElement();

    // Register the video element as a platform view
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType!,
      (int viewId) => _videoElement!,
    );

    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
        'audio': false,
      });
      _videoElement!.srcObject = stream;

      // Wait for the video metadata to load so dimensions are available
      final completer = Completer<void>();
      _videoElement!.onLoadedMetadata.first.then((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );

      _isReady = true;
      _error = null;
    } catch (e) {
      _isReady = false;
      _error = e.toString();
    }
  }

  Future<Uint8List?> captureFrame() async {
    if (!_isReady || _videoElement == null || _canvasElement == null) return null;

    final vw = _videoElement!.videoWidth;
    final vh = _videoElement!.videoHeight;
    if (vw == 0 || vh == 0) return null;

    _canvasElement!.width = vw;
    _canvasElement!.height = vh;

    final ctx = _canvasElement!.context2D;
    ctx.drawImage(_videoElement!, 0, 0);

    final dataUrl = _canvasElement!.toDataUrl('image/jpeg', 0.85);
    final base64Data = dataUrl.split(',')[1];
    return base64Decode(base64Data);
  }

  Future<List<Uint8List>> captureBurst(int count, Duration interval) async {
    final frames = <Uint8List>[];
    for (int i = 0; i < count; i++) {
      final frame = await captureFrame();
      if (frame != null) frames.add(frame);
      if (i < count - 1) await Future.delayed(interval);
    }
    return frames;
  }

  void dispose() {
    if (_videoElement?.srcObject != null) {
      final stream = _videoElement!.srcObject as html.MediaStream;
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    _videoElement?.remove();
  }
}

class WebCameraView extends StatelessWidget {
  final WebCameraController controller;
  const WebCameraView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.isReady || controller.viewType == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.cyanAccent),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }
    return HtmlElementView(viewType: controller.viewType!);
  }
}
