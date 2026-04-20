import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/api_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  CameraController? _cameraController;
  CameraDescription? _frontCamera;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String _statusMessage = 'Looking for a face...';
  int _failedAttempts = 0;
  Timer? _detectionTimer; // Android only
  bool _canProcess = true; // iOS stream guard

  // Theme color (Light Blue)
  final Color _primaryColor = const Color(0xFF89D3EE);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      _frontCamera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });

      if (Platform.isIOS) {
        _startIOSStream();
      } else {
        _startAndroidTimer();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) {
        setState(() {
          _statusMessage =
              'Camera initialization failed. Please check permissions.';
        });
      }
    }
  }

  // ── iOS: image stream (fast, no shutter flash) ──
  void _startIOSStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    _canProcess = true;
    _cameraController!.startImageStream((CameraImage image) {
      if (_canProcess && !_isProcessing) {
        _processIOSFrame(image);
      }
    });
  }

  Future<void> _processIOSFrame(CameraImage image) async {
    if (!mounted || _cameraController == null) return;
    _isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(
                _frontCamera!.sensorOrientation,
              ) ??
              InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'No face detected. Please position your face.';
        });
        _isProcessing = false;
        return;
      }

      // Face found — stop stream, capture photo for server
      _canProcess = false;
      await _cameraController!.stopImageStream();
      await _onFaceDetected();
    } catch (e) {
      debugPrint('iOS face detection error: $e');
      _isProcessing = false;
    }
  }

  // ── Android: timer + takePicture (reliable across devices) ──
  void _startAndroidTimer() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _processAndroidFrame(),
    );
  }

  void _stopAndroidTimer() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  Future<void> _processAndroidFrame() async {
    if (_isProcessing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    _isProcessing = true;

    try {
      final XFile photo = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final faces = await _faceDetector.processImage(inputImage);

      try {
        await File(photo.path).delete();
      } catch (_) {}

      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'No face detected. Please position your face.';
        });
        _isProcessing = false;
        return;
      }

      // Face found — stop timer, capture photo for server
      _stopAndroidTimer();
      await _onFaceDetected();
    } catch (e) {
      debugPrint('Android face detection error: $e');
      _isProcessing = false;
    }
  }

  // ── Shared: once a face is detected on either platform ──
  Future<void> _onFaceDetected() async {
    if (!mounted) return;

    setState(() {
      _statusMessage = 'Face detected! Capturing for verification...';
    });

    try {
      final XFile verifyPhoto = await _cameraController!.takePicture();

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Verifying identity...';
      });

      final response = await ApiService.verifyFace(verifyPhoto.path);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _statusMessage = 'Identity verification successful!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity Verified! Redirecting to Dashboard...'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          await ApiService.logout();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many failed attempts. Returning to login.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          return;
        }

        setState(() {
          _statusMessage =
              'Face not recognized.\n(${3 - _failedAttempts} attempts left)';
          _isProcessing = false;
        });

        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _restartDetection();
        }
      }
    } catch (e) {
      debugPrint('Verification error: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Verification error. Retrying...';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _restartDetection();
      }
    }
  }

  void _restartDetection() {
    if (Platform.isIOS) {
      _isProcessing = false;
      _startIOSStream();
    } else {
      _isProcessing = false;
      _startAndroidTimer();
    }
  }

  @override
  void dispose() {
    _stopAndroidTimer();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColorStart = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color bgColorEnd = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFEFF6FF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Facial ID',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: Stack(
          children: [
            // Glassmorphic background shapes
            Positioned(
              left: -50,
              top: 100,
              child: _buildBackgroundCircle(
                200,
                _primaryColor.withOpacity(0.15),
              ),
            ),
            Positioned(
              right: -80,
              bottom: 100,
              child: _buildBackgroundCircle(
                250,
                _primaryColor.withOpacity(0.1),
              ),
            ),
            Positioned(
              left: 40,
              bottom: -50,
              child: _buildBackgroundCircle(
                150,
                _primaryColor.withOpacity(0.12),
              ),
            ),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 100),

                  // Camera Section with Glass Frame
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow
                          Container(
                            width: 320,
                            height: 320,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryColor.withOpacity(0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),

                          // Camera Preview Circle
                          ClipOval(
                            child: Container(
                              width: 300,
                              height: 300,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: _isCameraInitialized
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                        // The camera aspect ratio is usually width/height.
                                        // For vertical orientation, we want the inverse or to scale correctly.
                                        double aspectRatio = _cameraController!
                                            .value
                                            .aspectRatio;

                                        // On most devices, aspectRatio is > 1.0 (landscape sensor)
                                        // We want to ensure the preview fills the square container (BoxFit.cover)
                                        return FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: constraints.maxWidth,
                                            // Multiply by aspectRatio if it's landscape to get portrait height
                                            height:
                                                constraints.maxWidth *
                                                aspectRatio,
                                            child: CameraPreview(
                                              _cameraController!,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                            ),
                          ),

                          // Dynamic Border Ring
                          Container(
                            width: 310,
                            height: 310,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isProcessing
                                    ? _primaryColor.withOpacity(0.5)
                                    : (_statusMessage.contains(
                                                'not recognized',
                                              ) ||
                                              _statusMessage.contains('error')
                                          ? Colors.redAccent.withOpacity(0.5)
                                          : Colors.greenAccent.withOpacity(
                                              0.5,
                                            )),
                                width: 2,
                              ),
                            ),
                          ),

                          // Processing Animated Ring
                          if (_isProcessing)
                            SizedBox(
                              width: 314,
                              height: 314,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Status / Instruction Overlay
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 40,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  (_statusMessage.contains('not recognized') ||
                                      _statusMessage.contains('error'))
                                  ? Colors.redAccent.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      (_statusMessage.contains(
                                            'not recognized',
                                          ) ||
                                          _statusMessage.contains('error'))
                                      ? Colors.redAccent.withOpacity(0.2)
                                      : _primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  (_statusMessage.contains('not recognized') ||
                                          _statusMessage.contains('error'))
                                      ? Icons.warning_amber_rounded
                                      : Icons.face_retouching_natural_rounded,
                                  color:
                                      (_statusMessage.contains(
                                            'not recognized',
                                          ) ||
                                          _statusMessage.contains('error'))
                                      ? Colors.redAccent
                                      : _primaryColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _statusMessage,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: size / 2,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
