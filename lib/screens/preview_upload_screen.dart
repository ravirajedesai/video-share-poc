import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/video_service.dart';

class PreviewUploadScreen extends StatefulWidget {
  final String videoPath;
  final int durationSeconds;

  const PreviewUploadScreen({
    super.key,
    required this.videoPath,
    required this.durationSeconds,
  });

  @override
  State<PreviewUploadScreen> createState() => _PreviewUploadScreenState();
}

class _PreviewUploadScreenState extends State<PreviewUploadScreen> {
  late VideoPlayerController _videoController;
  final TextEditingController _captionController = TextEditingController();
  final VideoService _videoService = VideoService();

  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _processAndUploadVideo() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Optimizing & generating thumbnail...';
    });

    try {
      final rawFile = File(widget.videoPath);

      // 1. Compress video and extract high quality thumbnail frame
      final result = await _videoService.compressAndGenerateThumbnail(rawFile);

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Uploading video & thumbnail to cloud...';
      });

      final videoId = DateTime.now().millisecondsSinceEpoch.toString();

      // 2. Upload thumbnail image (.jpg)
      final thumbnailUrl = await _videoService.uploadThumbnailToSupabase(
        file: result.thumbnailFile,
        videoId: videoId,
      );

      // 3. Upload compressed video (.mp4)
      final videoUrl = await _videoService.uploadVideoToSupabase(
        file: result.compressedVideo,
        videoId: videoId,
      );

      // 4. Save video record with thumbnail URL to Firestore
      await _videoService.saveVideoMetadata(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        caption: _captionController.text.trim(),
        durationSeconds: widget.durationSeconds,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded! Saved ${((1 - result.compressedSize / result.originalSize) * 100).toStringAsFixed(0)}% space.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Pop back to the main feed screen
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Preview & Post', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Playback
          if (_videoController.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Caption & Upload Actions
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      enabled: !_isProcessing,
                    ),
                    const SizedBox(height: 16),
                    if (_isProcessing) ...[
                      const LinearProgressIndicator(
                        backgroundColor: Colors.white24,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _processAndUploadVideo,
                          icon: const Icon(Icons.cloud_upload_rounded, color: Colors.black),
                          label: const Text(
                            'Post Video',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
