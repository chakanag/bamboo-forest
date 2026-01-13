import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/posts_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ttl_timer.dart';

class PostDetailScreen extends ConsumerWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));

    return Scaffold(
      appBar: AppBar(title: const Text('이야기 상세')),
      body: postAsync.when(
        data: (post) {
          final isBlinded = post.status != 'active' || post.reports >= 50;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags
                Wrap(
                  spacing: 8,
                  children: post.tags.map((tag) => Chip(
                    label: Text('#$tag'),
                    backgroundColor: AppTheme.bambooLight,
                    labelStyle: const TextStyle(color: AppTheme.bambooDeep),
                  )).toList(),
                ),
                const SizedBox(height: 20),

                // Content
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    isBlinded ? '많은 신고로 인해 가려진 게시글입니다.' : post.content,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      color: isBlinded ? AppTheme.textSub : AppTheme.textMain,
                      fontStyle: isBlinded ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Timer
                if (!isBlinded)
                  TtlTimer(
                    createdAt: post.createdAt,
                    ttlSeconds: post.ttlSeconds,
                  ),

                const SizedBox(height: 40),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.favorite_rounded,
                      label: '${post.recommendations} 공감',
                      color: AppTheme.bambooMedium,
                      onTap: () async {
                        final success = await ref.read(apiServiceProvider).recommendPost(postId);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('공감했습니다! 시간이 연장됩니다.')),
                          );
                          ref.invalidate(postDetailProvider(postId));
                          ref.invalidate(postsProvider);
                        }
                      },
                    ),
                    _ActionButton(
                      icon: Icons.report_problem_rounded,
                      label: '신고',
                      color: AppTheme.alertRed,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('신고하시겠습니까?'),
                            content: const Text('부적절한 내용인가요?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true), 
                                child: const Text('신고', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final success = await ref.read(apiServiceProvider).reportPost(postId);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('신고가 접수되었습니다.')),
                            );
                            ref.invalidate(postDetailProvider(postId));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 500.ms),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('오류: $err')),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
  }
}
