import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import '../models/video_model.dart';

class VideoProcessingResult {
  final File compressedVideo;
  final File thumbnailFile;
  final int originalSize;
  final int compressedSize;

  VideoProcessingResult({
    required this.compressedVideo,
    required this.thumbnailFile,
    required this.originalSize,
    required this.compressedSize,
  });
}

class VideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of community videos from Firestore
  Stream<List<VideoModel>> getVideosFeed() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList());
  }

  // Compress video and generate a real image thumbnail
  Future<VideoProcessingResult> compressAndGenerateThumbnail(File rawVideoFile) async {
    final originalSize = await rawVideoFile.length();

    // 1. Generate thumbnail image (.jpg)
    final thumbnailFile = await VideoCompress.getFileThumbnail(
      rawVideoFile.path,
      quality: 75,
      position: -1, // extracts middle frame
    );

    // 2. Compress video (medium quality, keeps 1080/720p crisp with ~60-80% smaller size)
    final mediaInfo = await VideoCompress.compressVideo(
      rawVideoFile.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
      includeAudio: true,
    );

    final compressedFile = mediaInfo?.file ?? rawVideoFile;
    final compressedSize = await compressedFile.length();

    debugPrint(
      'Video compressed from ${(originalSize / (1024 * 1024)).toStringAsFixed(1)} MB '
      'to ${(compressedSize / (1024 * 1024)).toStringAsFixed(1)} MB',
    );

    return VideoProcessingResult(
      compressedVideo: compressedFile,
      thumbnailFile: thumbnailFile,
      originalSize: originalSize,
      compressedSize: compressedSize,
    );
  }

  // Upload video file directly to Supabase Storage bucket ('videos')
  Future<String> uploadVideoToSupabase({
    required File file,
    required String videoId,
  }) async {
    final fileName = '$videoId.mp4';
    final storage = Supabase.instance.client.storage.from('videos');

    await storage.upload(
      fileName,
      file,
      fileOptions: const FileOptions(
        contentType: 'video/mp4',
        upsert: true,
      ),
    );

    return storage.getPublicUrl(fileName);
  }

  // Upload thumbnail image directly to Supabase Storage bucket ('videos')
  Future<String> uploadThumbnailToSupabase({
    required File file,
    required String videoId,
  }) async {
    final fileName = '${videoId}_thumb.jpg';
    final storage = Supabase.instance.client.storage.from('videos');

    await storage.upload(
      fileName,
      file,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    return storage.getPublicUrl(fileName);
  }

  // Save video record to Firestore
  Future<void> saveVideoMetadata({
    required String videoUrl,
    required String thumbnailUrl,
    required String caption,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    await _firestore.collection('videos').add({
      'userId': userId,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'durationSeconds': durationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'published',
    });
  }

  // Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Delete video from both Firestore and Supabase Storage
  Future<void> deleteVideo({
    required String videoId,
    required String videoUrl,
    required String thumbnailUrl,
  }) async {
    // 1. Delete document from Firestore
    await _firestore.collection('videos').doc(videoId).delete();

    // 2. Delete files from Supabase Storage
    try {
      final storage = Supabase.instance.client.storage.from('videos');
      final videoFileName = videoUrl.split('/').last.split('?').first;
      final thumbFileName = thumbnailUrl.split('/').last.split('?').first;

      final filesToRemove = <String>[];
      if (videoFileName.isNotEmpty) filesToRemove.add(videoFileName);
      if (thumbFileName.isNotEmpty) filesToRemove.add(thumbFileName);

      if (filesToRemove.isNotEmpty) {
        await storage.remove(filesToRemove);
      }
    } catch (e) {
      debugPrint('Storage cleanup note: $e');
    }
  }

  // Cancel any running compression operations
  Future<void> cancelCompression() async {
    await VideoCompress.cancelCompression();
  }
}
