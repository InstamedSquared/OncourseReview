import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
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
  final FaceDetector _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
    enableContours: true,
    enableClassification: true,
    performanceMode: FaceDetectorMode.accurate,
  ));
  
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  String _statusMessage = 'Looking for a face...';
  Timer? _timer;
  int _failedAttempts = 0;

  // Theme color (Light Blue)
  final Color _primaryColor = const Color(0xFF89D3EE);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    // Try to find a front-facing camera
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      // Force orientation to portrait to ensure ML Kit gets upright images
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
      
      // Start auto-verify loop
      _startTimer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Camera initialization failed. Please check permissions.';
        });
      }
    }
  }
  
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isProcessing && _isCameraInitialized && mounted) {
        _captureAndVerify();
      }
    });
  }

  Future<void> _captureAndVerify() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Capture the image
      final XFile imageFile = await _cameraController!.takePicture();

      // 2. Local Face Detection (to ensure there is a face before sending to server)
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = 'No face detected. Please position your face.';
            _isProcessing = false;
          });
        }
        return;
      }
      if (faces.length > 1) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Multiple faces detected. Please ensure only you are in the frame.';
            _isProcessing = false;
          });
        }
        return;
      }

      // We found a face! Pause auto-checks and verify via API.
      _timer?.cancel();
      if (mounted) {
        setState(() {
            _statusMessage = 'Face detected! Verifying identity...';
        });
      }

      // 3. Send image to server for Facial Verification
      final response = await ApiService.verifyFace(imageFile.path);

      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Identity verification successful!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Identity Verified! Redirecting to Dashboard...'),
                backgroundColor: Colors.green),
          );
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const MainShell()));
        }
      } else {
        if (mounted) {
          _failedAttempts++;
          if (_failedAttempts >= 3) {
            _timer?.cancel();
            await ApiService.logout();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Too many failed attempts. Returning to login.'),
                backgroundColor: Colors.redAccent,
              ),
            );
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            return;
          }

          setState(() {
            // Reverted to clean, user-friendly message
            _statusMessage = 'Face not recognized.\n(${3 - _failedAttempts} attempts left)';
          });
          
          // Wait briefly, then resume looking for a face
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
             _startTimer();
             setState(() => _isProcessing = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'An error occurred. Retrying...';
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
           _startTimer();
           setState(() => _isProcessing = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColorStart = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color bgColorEnd = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
              child: _buildBackgroundCircle(200, _primaryColor.withOpacity(0.15)),
            ),
            Positioned(
              right: -80,
              bottom: 100,
              child: _buildBackgroundCircle(250, _primaryColor.withOpacity(0.1)),
            ),
            Positioned(
              left: 40,
              bottom: -50,
              child: _buildBackgroundCircle(150, _primaryColor.withOpacity(0.12)),
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
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                              ),
                              child: _isCameraInitialized
                                  ? LayoutBuilder(
                                      builder: (context, constraints) {
                                        // The camera aspect ratio is usually width/height.
                                        // For vertical orientation, we want the inverse or to scale correctly.
                                        double aspectRatio = _cameraController!.value.aspectRatio;
                                        
                                        // On most devices, aspectRatio is > 1.0 (landscape sensor)
                                        // We want to ensure the preview fills the square container (BoxFit.cover)
                                        return FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: constraints.maxWidth,
                                            // Multiply by aspectRatio if it's landscape to get portrait height
                                            height: constraints.maxWidth * aspectRatio,
                                            child: CameraPreview(_cameraController!),
                                          ),
                                        );
                                      },
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
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
                                    : (_statusMessage.contains('not recognized') || _statusMessage.contains('error') 
                                        ? Colors.redAccent.withOpacity(0.5) 
                                        : Colors.greenAccent.withOpacity(0.5)),
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
                                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Status / Instruction Overlay
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: (_statusMessage.contains('not recognized') || _statusMessage.contains('error'))
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
                                  color: (_statusMessage.contains('not recognized') || _statusMessage.contains('error'))
                                      ? Colors.redAccent.withOpacity(0.2)
                                      : _primaryColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  (_statusMessage.contains('not recognized') || _statusMessage.contains('error'))
                                      ? Icons.warning_amber_rounded
                                      : Icons.face_retouching_natural_rounded,
                                  color: (_statusMessage.contains('not recognized') || _statusMessage.contains('error'))
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
                                    color: isDark ? Colors.white : Colors.black87,
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
