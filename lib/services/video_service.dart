import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_model.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream of community videos for the feed
  Stream<List<VideoModel>> getVideosFeed() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList());
  }

  // Upload video file with progress callback
  UploadTask uploadVideoFile({
    required File file,
    required String videoId,
  }) {
    final storageRef = _storage.ref().child('videos/$videoId.mp4');
    return storageRef.putFile(
      file,
      SettableMetadata(contentType: 'video/mp4'),
    );
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
