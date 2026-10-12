import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String userId;
  final String videoUrl;
  final String caption;
  final DateTime createdAt;
  final int durationSeconds;

  VideoModel({
    required this.id,
    required this.userId,
    required this.videoUrl,
    required this.caption,
    required this.createdAt,
    required this.durationSeconds,
  });

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VideoModel(
      id: doc.id,
      userId: data['userId'] as String? ?? 'anonymous',
      videoUrl: data['videoUrl'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'videoUrl': videoUrl,
      'caption': caption,
      'createdAt': FieldValue.serverTimestamp(),
      'durationSeconds': durationSeconds,
      'status': 'published', // PoC direct publish
    };
  }
}
