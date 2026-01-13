import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';
import '../widgets/post_card.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'ranking_screen.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('익명 대나무숲'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RankingScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(postsProvider.notifier).refresh(),
        color: AppTheme.bambooDeep,
        child: postsAsync.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forest_outlined, size: 64, color: AppTheme.bambooMedium.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text('아직 심어진 대나무가 없습니다.\n첫 번째 이야기를 들려주세요.', 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSub),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(postId: post.id),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.bambooDeep),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.alertRed),
                const SizedBox(height: 16),
                Text('오류가 발생했습니다: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(postsProvider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
