import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';
import '../theme/app_theme.dart';

class PostDetailScreen extends ConsumerWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('이야기 상세')),
      body: postAsync.when(
        data: (post) {
          final isBlinded = post.status != 'active' || post.reports >= 50;

          // 태그 칩 색상
          final tagBg = isDark
              ? scheme.onSurface.withOpacity(0.10)
              : AppTheme.purpleLight;
          final tagTextColor = scheme.primary;

          // 본문 컨테이너 색상
          final contentBg = isDark ? scheme.surface : Colors.white;
          final shadowColor = isDark
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.05);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 태그
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: post.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              color: tagTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),

                // 본문
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: contentBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
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
                      color: isBlinded
                          ? scheme.onSurface.withOpacity(0.4)
                          : scheme.onSurface,
                      fontStyle:
                          isBlinded ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 소멸 안내
                if (!isBlinded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.blur_on_outlined,
                          size: 13,
                          color: scheme.onSurface.withOpacity(0.30),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '이 마음은 곧 사라져요',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurface.withOpacity(0.30),
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // 공감 / 신고 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.favorite_rounded,
                      label: '${post.recommendations} 공감',
                      color: scheme.primary,
                      onTap: () async {
                        final success = await ref
                            .read(apiServiceProvider)
                            .recommendPost(postId);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('공감했습니다! 시간이 연장됩니다.'),
                            ),
                          );
                          ref.invalidate(postDetailProvider(postId));
                          ref.invalidate(postsProvider);
                        }
                      },
                    ),
                    _ActionButton(
                      icon: Icons.report_problem_rounded,
                      label: '신고',
                      color: scheme.error,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('신고하시겠습니까?'),
                            content: const Text('부적절한 내용인가요?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: Text(
                                  '신고',
                                  style: TextStyle(color: scheme.error),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final success = await ref
                              .read(apiServiceProvider)
                              .reportPost(postId);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('신고가 접수되었습니다.'),
                              ),
                            );
                            ref.invalidate(postDetailProvider(postId));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (err, stack) => Center(
          child: Text(
            '오류: $err',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

// ── 액션 버튼 ──────────────────────────────────────────────────────────────────
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
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.30)),
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
    );
  }
}
