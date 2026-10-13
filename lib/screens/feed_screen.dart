import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';
import 'camera_screen.dart';
import 'single_video_player_screen.dart';

class FeedScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FeedScreen({super.key, required this.cameras});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final VideoService _videoService = VideoService();
  bool _isAdmin = false;

  void _promptAdminMode() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        title: const Text('Admin Mode', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Admin PIN to enable deletion of any video:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'PIN (default: 1234)',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              if (pinController.text.trim() == '1234') {
                setState(() => _isAdmin = !_isAdmin);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isAdmin ? 'Admin mode enabled: You can delete any video' : 'Admin mode disabled',
                    ),
                    backgroundColor: _isAdmin ? Colors.redAccent : Colors.grey,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN')),
                );
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: GestureDetector(
          onLongPress: _promptAdminMode, // Secret long-press on title to toggle Admin mode
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Community Videos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (_isAdmin) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.amber, size: 28),
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
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
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
                  const Icon(Icons.video_library_outlined, size: 72, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text(
                    'No videos uploaded yet.',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(cameras: widget.cameras),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Record First Video'),
                  ),
                ],
              ),
            );
          }

          // 2-Column Grid of video thumbnails/cards
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: GridView.builder(
              itemCount: videos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final video = videos[index];
                return VideoGridCard(
                  video: video,
                  index: index,
                  onTap: () {
                    // Open and play only THIS video
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SingleVideoPlayerScreen(
                          video: video,
                          isAdmin: _isAdmin,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class VideoGridCard extends StatelessWidget {
  final VideoModel video;
  final int index;
  final VoidCallback onTap;

  const VideoGridCard({
    super.key,
    required this.video,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMM d, h:mm a').format(video.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Thumbnail / Play Icon Area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: video.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade900,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.amber,
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildPlaceholder(),
                  ),

                  // Semi-transparent center play icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Duration badge in top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${video.durationSeconds}s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Video index badge in top left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Video Details / Caption
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.caption.isNotEmpty ? video.caption : 'Video #${index + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
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

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.movie_creation_outlined,
            size: 32,
            color: Colors.amber,
          ),
        ),
      ),
    );
  }
}
