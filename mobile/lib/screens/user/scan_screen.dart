import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/routes.dart';
import '../../services/api_service.dart';
import '../../services/camera_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final ApiService _apiService = ApiService();
  bool _isPermissionsGranted = false;
  bool _isProcessing = false;
  String _statusMessage = "Position your face in the oval";

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      setState(() {
        _isPermissionsGranted = true;
      });
      _initializeCamera();
      return;
    }

    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isGranted) {
      setState(() {
        _isPermissionsGranted = true;
      });
      _initializeCamera();
    } else {
      setState(() {
        _statusMessage = "Camera permission is required.";
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final success = await _cameraService.initialize();
      if (mounted) {
        setState(() {
          if (!success) {
            _statusMessage = "Camera check: No device found. Make sure webcam is plugged in.";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Camera error: $e";
        });
      }
    }
  }

  Future<void> _startScanFlow() async {
    if (_isProcessing || !_cameraService.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Authenticating... Keep still";
    });

    try {
      // Capture a burst of 3 frames for liveness detection
      final frames = await _cameraService.captureBurst(3, const Duration(milliseconds: 300));
      if (frames.isEmpty) {
        throw Exception("Failed to capture images.");
      }

      // Verify with Backend
      final result = await _apiService.verifyFace(frames);

      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.result,
          arguments: result,
        ).then((_) {
          // Reset when coming back
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = "Position your face in the oval";
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.result,
          arguments: {
            'result': 'denied',
            'reason': e.toString(),
          },
        ).then((_) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
              _statusMessage = "Position your face in the oval";
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          if (_isPermissionsGranted && _cameraService.controller != null && _cameraService.controller!.value.isInitialized)
            SizedBox(
              width: size.width,
              height: size.height,
              child: CameraPreview(_cameraService.controller!),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(_statusMessage, style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),

          // Custom Sci-Fi Overlay
          if (_isPermissionsGranted && _cameraService.controller != null && _cameraService.controller!.value.isInitialized)
            CustomPaint(
              size: size,
              painter: FaceScannerOverlayPainter(),
            ),

          // Pulsing Guide Oval Frame
          if (_isPermissionsGranted && _cameraService.controller != null && _cameraService.controller!.value.isInitialized)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: size.width * 0.72,
                      height: size.height * 0.42,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isProcessing ? theme.colorScheme.primary : theme.colorScheme.secondary,
                          width: 3.0,
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.elliptical(size.width * 0.36, size.height * 0.21),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isProcessing ? theme.colorScheme.primary : theme.colorScheme.secondary).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Top Bar Info
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "FaceGuard Portal",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.cyanAccent),
                          SizedBox(width: 4),
                          Text(
                            "SECURE TERMINAL",
                            style: TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.adminLogin);
                  },
                ),
              ],
            ),
          ),

          // Scanning Line
          if (_isProcessing)
            AnimatedScannerLine(size: size, theme: theme),

          // Status & Capture Actions
          Positioned(
            bottom: 60,
            left: 32,
            right: 32,
            child: Column(
              children: [
                // Status Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                        )
                      else
                        const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Capture Button
                if (!_isProcessing)
                  GestureDetector(
                    onTap: _startScanFlow,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 4),
                      ),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.secondary.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fingerprint,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to darken the areas outside the oval
class FaceScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);

    // Bounding Box
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Oval Cutout
    final ovalPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.72,
          height: size.height * 0.42,
        ),
      );

    // Subtract the oval from the background
    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, ovalPath);

    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Scanning Line Widget
class AnimatedScannerLine extends StatefulWidget {
  final Size size;
  final ThemeData theme;
  const AnimatedScannerLine({super.key, required this.size, required this.theme});

  @override
  State<AnimatedScannerLine> createState() => _AnimatedScannerLineState();
}

class _AnimatedScannerLineState extends State<AnimatedScannerLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Line moves from top of oval to bottom of oval
    final start = widget.size.height / 2 - widget.size.height * 0.21;
    final end = widget.size.height / 2 + widget.size.height * 0.21;

    _animation = Tween<double>(begin: start, end: end).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widthOffset = (widget.size.width - widget.size.width * 0.72) / 2;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          top: _animation.value,
          left: widthOffset + 10,
          right: widthOffset + 10,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: widget.theme.colorScheme.secondary,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  widget.theme.colorScheme.secondary.withOpacity(0.1),
                  widget.theme.colorScheme.secondary,
                  widget.theme.colorScheme.secondary.withOpacity(0.1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
