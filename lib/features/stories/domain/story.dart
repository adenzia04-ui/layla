import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Optional emotional tag on a story. Deliberately about the writer's own
/// state — never about outcomes or results.
enum StoryMood {
  peaceful('peaceful', 'Peaceful', Icons.spa_outlined),
  grateful('grateful', 'Grateful', Icons.favorite_outline_rounded),
  hopeful('hopeful', 'Hopeful', Icons.wb_twilight_rounded),
  tested('tested', 'Going through something', Icons.waves_rounded),
  reflective('reflective', 'Reflective', Icons.self_improvement_rounded);

  const StoryMood(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static StoryMood fromKey(String? key) => StoryMood.values.firstWhere(
    (StoryMood m) => m.key == key,
    orElse: () => StoryMood.reflective,
  );
}

enum StoryStatus {
  published('published'),

  /// Hidden from the feed pending a look, after enough reports.
  underReview('under_review'),
  removed('removed');

  const StoryStatus(this.key);

  final String key;

  static StoryStatus fromKey(String? key) => StoryStatus.values.firstWhere(
    (StoryStatus s) => s.key == key,
    orElse: () => StoryStatus.published,
  );
}

@immutable
class Story {
  const Story({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.body,
    required this.mood,
    required this.createdAt,
    this.status = StoryStatus.published,
    this.likeCount = 0,
    this.isAnonymous = false,
    this.likedByMe = false,
  });

  final String id;
  final String uid;
  final String authorName;
  final String body;
  final StoryMood mood;
  final DateTime createdAt;
  final StoryStatus status;
  final int likeCount;
  final bool isAnonymous;

  /// Filled in per-viewer by the repository, not stored on the document.
  final bool likedByMe;

  String get displayAuthor => isAnonymous ? 'A believer' : authorName;

  factory Story.fromDoc(
    DocumentSnapshot<Map<String, Object?>> doc, {
    bool likedByMe = false,
  }) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    return Story(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'A believer',
      body: data['body'] as String? ?? '',
      mood: StoryMood.fromKey(data['mood'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: StoryStatus.fromKey(data['status'] as String?),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      likedByMe: likedByMe,
    );
  }

  Story copyWith({int? likeCount, bool? likedByMe}) => Story(
    id: id,
    uid: uid,
    authorName: authorName,
    body: body,
    mood: mood,
    createdAt: createdAt,
    status: status,
    likeCount: likeCount ?? this.likeCount,
    isAnonymous: isAnonymous,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}

/// Why a story was reported. Kept short and specific so moderation decisions
/// are consistent.
enum ReportReason {
  harmful('harmful', 'Harmful or hateful'),
  misleading('misleading', 'Presents claims as guaranteed religious outcomes'),
  spam('spam', 'Spam, advertising or a link'),
  privacy('privacy', 'Shares private information about someone'),
  other('other', 'Something else');

  const ReportReason(this.key, this.label);

  final String key;
  final String label;
}
