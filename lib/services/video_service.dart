import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/video_model.dart';

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

  // Upload video file directly to Supabase Storage bucket ('videos')
  Future<String> uploadVideoToSupabase({
    required File file,
    required String videoId,
  }) async {
    final fileName = '$videoId.mp4';
    final storage = Supabase.instance.client.storage.from('videos');

    // Upload file
    await storage.upload(
      fileName,
      file,
      fileOptions: const FileOptions(
        contentType: 'video/mp4',
        upsert: true,
      ),
    );

    // Get public URL
    final publicUrl = storage.getPublicUrl(fileName);
    return publicUrl;
  }

  // Save video record to Firestore
  Future<void> saveVideoMetadata({
    required String videoUrl,
    required String caption,
    required int durationSeconds,
  }) async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    await _firestore.collection('videos').add({
      'userId': userId,
      'videoUrl': videoUrl,
      'caption': caption,
      'durationSeconds': durationSeconds,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'published',
    });
  }
}
