import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/story_repository.dart';
import '../domain/story.dart';

final StreamProvider<List<Story>> storyFeedProvider =
    StreamProvider<List<Story>>(
  (Ref ref) => ref.watch(storyRepositoryProvider).watchFeed(),
);

final StreamProvider<List<Story>> myStoriesProvider =
    StreamProvider<List<Story>>(
  (Ref ref) => ref.watch(storyRepositoryProvider).watchMine(),
);

final StreamProviderFamily<Story?, String> storyProvider =
    StreamProvider.family<Story?, String>(
  (Ref ref, String id) => ref.watch(storyRepositoryProvider).watchStory(id),
);

final FutureProviderFamily<bool, String> hasLikedProvider =
    FutureProvider.family<bool, String>(
  (Ref ref, String id) => ref.watch(storyRepositoryProvider).hasLiked(id),
);

final AutoDisposeAsyncNotifierProvider<StoryController, void>
    storyControllerProvider =
    AsyncNotifierProvider.autoDispose<StoryController, void>(
  StoryController.new,
);

class StoryController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  StoryRepository get _repo => ref.read(storyRepositoryProvider);

  Future<String?> publish({
    required String body,
    required StoryMood mood,
    required bool anonymous,
  }) async {
    state = const AsyncValue<void>.loading();
    String? id;
    state = await AsyncValue.guard(() async {
      id = await _repo.publish(body: body, mood: mood, anonymous: anonymous);
    });
    return state.hasError ? null : id;
  }

  Future<void> toggleLike(String storyId) async {
    await _repo.toggleLike(storyId);
    ref.invalidate(hasLikedProvider(storyId));
  }

  Future<bool> report({
    required String storyId,
    required ReportReason reason,
    String note = '',
  }) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(
      () => _repo.report(storyId: storyId, reason: reason, note: note),
    );
    return !state.hasError;
  }

  Future<bool> delete(String storyId) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() => _repo.deleteMine(storyId));
    return !state.hasError;
  }
}
