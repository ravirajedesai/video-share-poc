import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';

class SingleVideoPlayerScreen extends StatefulWidget {
  final VideoModel video;
  final bool isAdmin;

  const SingleVideoPlayerScreen({
    super.key,
    required this.video,
    this.isAdmin = false,
  });

  @override
  State<SingleVideoPlayerScreen> createState() => _SingleVideoPlayerScreenState();
}

class _SingleVideoPlayerScreenState extends State<SingleVideoPlayerScreen> {
  late VideoPlayerController _controller;
  final VideoService _videoService = VideoService();
  bool _isPlaying = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
      ..initialize().then((_) {
        _controller.setLooping(true);
        _controller.play();
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Delete Video', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this video? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _videoService.deleteVideo(
        videoId: widget.video.id,
        videoUrl: widget.video.videoUrl,
        thumbnailUrl: widget.video.thumbnailUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video deleted successfully!'),
          backgroundColor: Colors.redAccent,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _videoService.currentUserId;
    final isOwner = currentUserId.isNotEmpty && currentUserId == widget.video.userId;
    final canDelete = isOwner || widget.isAdmin;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.video.caption.isNotEmpty ? widget.video.caption : 'Video Player',
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (canDelete)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: isOwner ? 'Delete your video' : 'Admin Delete',
                    onPressed: _confirmAndDelete,
                  ),
        ],
      ),
      body: GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.amber)),

            // Play / Pause overlay
            if (!_isPlaying && _controller.value.isInitialized)
              const Center(
                child: Icon(Icons.play_circle_fill, size: 75, color: Colors.white70),
              ),

            // Video information overlay at bottom
            Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.video.caption.isNotEmpty)
                        Text(
                          widget.video.caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Duration: ${widget.video.durationSeconds}s',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'You uploaded this',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
