import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';
import '../models/post.dart';
import 'post_detail_screen.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('명예의 전당'),
          bottom: TabBar(
            // TabBar 색상은 darkTheme의 tabBarTheme에서 자동 적용
            tabs: const [
              Tab(text: '최다 조회'),
              Tab(text: '최다 공감'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RankingList(type: 'views'),
            _RankingList(type: 'recs'),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends ConsumerWidget {
  final String type;

  const _RankingList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingAsync = ref.watch(rankingProvider(type));

    return rankingAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text(
              '랭킹 데이터가 없습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        return ListView.builder(
          itemCount: posts.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final post = posts[index];
            return _RankingItem(
              post: post,
              rank: index + 1,
              type: type,
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
    );
  }
}

class _RankingItem extends StatelessWidget {
  final Post post;
  final int rank;
  final String type;
  final VoidCallback onTap;

  const _RankingItem({
    required this.post,
    required this.rank,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 메달 색상 — 다크모드도 동일하게 유지 (메달은 원래 색이어야 함)
    Color? medalColor;
    if (rank == 1) medalColor = const Color(0xFFFFD700);
    else if (rank == 2) medalColor = const Color(0xFFC0C0C0);
    else if (rank == 3) medalColor = const Color(0xFFCD7F32);

    // 숫자 배지 배경 — 메달 없는 경우 다크모드 대응
    final rankBg = medalColor?.withOpacity(0.15) ??
        (isDark
            ? scheme.onSurface.withOpacity(0.08)
            : Colors.grey[100]);

    // 통계 배지 색상
    final badgeBg = isDark
        ? scheme.primary.withOpacity(0.15)
        : scheme.primary.withOpacity(0.12);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rankBg,
            shape: BoxShape.circle,
            border: medalColor != null
                ? Border.all(color: medalColor, width: 2)
                : null,
          ),
          child: Text(
            rank.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: medalColor ?? scheme.onSurface.withOpacity(0.4),
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          post.content,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            type == 'views'
                ? '${post.views}회'
                : '${post.recommendations}개',
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
