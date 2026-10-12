import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';
import 'camera_screen.dart';

class FeedScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FeedScreen({super.key, required this.cameras});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final VideoService _videoService = VideoService();
  int _focusedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Community Videos', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.amber, size: 30),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CameraScreen(cameras: widget.cameras),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<VideoModel>>(
        stream: _videoService.getVideosFeed(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading videos: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          final videos = snapshot.data ?? [];

          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_collection_outlined, size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'No videos uploaded yet.',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(cameras: widget.cameras),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.black),
                    label: const Text('Record First Video', style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
          }

          // Full-screen vertical swipe Reels-style feed
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) {
              setState(() {
                _focusedIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return VideoPlayerItem(
                key: ValueKey(videos[index].id),
                video: videos[index],
                isFocused: _focusedIndex == index,
              );
            },
          );
        },
      ),
    );
  }
}

class VideoPlayerItem extends StatefulWidget {
  final VideoModel video;
  final bool isFocused;

  const VideoPlayerItem({
    super.key,
    required this.video,
    required this.isFocused,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
      ..initialize().then((_) {
        _controller.setLooping(true);
        if (widget.isFocused) {
          _controller.play();
        } else {
          _controller.pause();
        }
        if (mounted) setState(() {});
      });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.value.isInitialized) {
      if (widget.isFocused) {
        _controller.play();
        _isPlaying = true;
      } else {
        _controller.pause();
        _isPlaying = false;
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Play / Pause Icon overlay
          if (!_isPlaying && _controller.value.isInitialized)
            const Center(
              child: Icon(Icons.play_circle_fill, size: 70, color: Colors.white70),
            ),

          // Caption and Details overlay
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.all(16.0),
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Recorded: ${widget.video.durationSeconds}s',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
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
