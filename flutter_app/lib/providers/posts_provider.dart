import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<Post>>(() {
  return PostsNotifier();
});

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    final apiService = ref.read(apiServiceProvider);
    return apiService.getPosts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final apiService = ref.read(apiServiceProvider);
      return apiService.getPosts();
    });
  }

  Future<void> addPost(String content) async {
    final apiService = ref.read(apiServiceProvider);
    // Optimistic update could be done here, but since we need the ID/Tags from server, we just wait.
    await apiService.createPost(content);
    // Refresh list to show new post
    await refresh();
  }
}

final postDetailProvider = FutureProvider.family<Post, String>((ref, id) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getPost(id);
});

final rankingProvider = FutureProvider.family<List<Post>, String>((ref, type) async {
  final apiService = ref.read(apiServiceProvider);
  return apiService.getRanking(type);
});
