import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'preview_upload_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isRecording = false;
  int _secondsRecorded = 0;
  Timer? _timer;
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isNotEmpty) {
      _initCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initCamera(int index) async {
    final camera = widget.cameras[index];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing camera: $e')),
        );
      }
    }
  }

  void _switchCamera() {
    if (widget.cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    _initCamera(_selectedCameraIndex);
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _secondsRecorded = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _secondsRecorded++;
        });

        // Hard limit at 60 seconds
        if (_secondsRecorded >= 60) {
          _stopRecording();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    try {
      final file = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });

      if (!mounted) return;

      // Navigate to preview and upload screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PreviewUploadScreen(
            videoPath: file.path,
            durationSeconds: _secondsRecorded,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_controller!),
          ),

          // Top Header (Timer / Progress bar)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Linear progress of 60 seconds
                    LinearProgressIndicator(
                      value: _secondsRecorded / 60.0,
                      backgroundColor: Colors.white24,
                      color: _secondsRecorded >= 50 ? Colors.redAccent : Colors.amber,
                      minHeight: 4,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_secondsRecorded.toString().padLeft(2, '0')}s / 60s',
                            style: TextStyle(
                              color: _secondsRecorded >= 50 ? Colors.redAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (widget.cameras.length > 1)
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                            onPressed: _isRecording ? null : _switchCamera,
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Controls (Record / Stop Button)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36.0),
              child: GestureDetector(
                onTap: () {
                  if (_isRecording) {
                    _stopRecording();
                  } else {
                    _startRecording();
                  }
                },
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: _isRecording ? 32 : 62,
                      width: _isRecording ? 32 : 62,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(_isRecording ? 8 : 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
