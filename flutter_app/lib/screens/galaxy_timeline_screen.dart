import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'ranking_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 메인 홈 화면 — Flat & Clean 피드
// ═══════════════════════════════════════════════════════════════════════════════
class GalaxyTimelineScreen extends ConsumerStatefulWidget {
  const GalaxyTimelineScreen({super.key});

  @override
  ConsumerState<GalaxyTimelineScreen> createState() =>
      _GalaxyTimelineScreenState();
}

class _GalaxyTimelineScreenState extends ConsumerState<GalaxyTimelineScreen>
    with SingleTickerProviderStateMixin {
  // 앱바 로고 (블랙홀) 애니메이션
  late final AnimationController _logoCtrl;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsAsync = ref.watch(postsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Center(
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(28, 28),
              painter: _BlackholePainter(_logoCtrl.value, isDark),
            ),
          ),
        ),
        title: Text(
          'Yeongi',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: '랭킹',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RankingScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return _EmptyView(logoCtrl: _logoCtrl, isDark: isDark);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(postsProvider.notifier).refresh(),
            color: scheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 4, bottom: 96),
              itemCount: posts.length,
              itemBuilder: (_, i) {
                final post = posts[i];
                return PostCard(
                  post: post,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(postId: post.id),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: scheme.error, size: 48),
              const SizedBox(height: 16),
              Text('오류: $err',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(postsProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
          if (mounted) ref.read(postsProvider.notifier).refresh();
        },
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

// ── 빈 화면 ───────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  final AnimationController logoCtrl;
  final bool isDark;

  const _EmptyView({required this.logoCtrl, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: logoCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(56, 56),
              painter: _BlackholePainter(logoCtrl.value, isDark),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Yeongi',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '마음도 지워질 자유가 있다',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '잠깐이었어도 진심이야.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 블랙홀 로고 CustomPainter
//   ① 바깥 헤일로 → ② 강착원반 뒷면 → ③ 사건지평선 → ④ 광자구 링
//   → ⑤ 강착원반 앞면 → ⑥ 중력렌즈 아크
// ═══════════════════════════════════════════════════════════════════════════════
class _BlackholePainter extends CustomPainter {
  final double t; // 0.0 ~ 1.0 반복
  final bool isDark;

  _BlackholePainter(this.t, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R = size.width / 2 - 0.5;

    // ① 바깥 헤일로 — 보라빛 발광
    final halo = 0.14 + math.sin(t * math.pi * 2) * 0.07;
    canvas.drawCircle(
      Offset(cx, cy),
      R,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFC084FC).withOpacity(halo),
            Colors.transparent,
          ],
          stops: const [0.50, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: R)),
    );

    // ② 강착원반 뒷면
    _drawDisk(canvas, cx, cy, R, front: false);

    // ③ 사건지평선 — 순수 검정
    canvas.drawCircle(
        Offset(cx, cy), R * 0.37, Paint()..color = Colors.black);

    // ④ 광자구 링
    canvas.drawCircle(
      Offset(cx, cy),
      R * 0.43,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      R * 0.47,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFFC084FC).withOpacity(0.42),
    );

    // ⑤ 강착원반 앞면
    _drawDisk(canvas, cx, cy, R, front: true);

    // ⑥ 중력렌즈 아크
    _drawLensingArcs(canvas, cx, cy, R);
  }

  void _drawDisk(Canvas canvas, double cx, double cy, double R,
      {required bool front}) {
    final diskRect = Rect.fromCenter(
      center: Offset(cx, cy + R * 0.06),
      width: R * 1.68,
      height: R * 0.50,
    );

    final hotspot = t * math.pi * 2;
    final brightFront = 0.70 + 0.25 * math.sin(hotspot).abs();
    final brightBack = 0.26 + 0.10 * math.cos(hotspot).abs();

    final layers = <({double w, Color cf, Color cb})>[
      (
        w: R * 0.17,
        cf: const Color(0xFFFFE566),
        cb: const Color(0xFFCC8800)
      ),
      (
        w: R * 0.11,
        cf: const Color(0xFFF97316),
        cb: const Color(0xFFAA4400)
      ),
      (
        w: R * 0.07,
        cf: const Color(0xFFC084FC),
        cb: const Color(0xFF7C3AED)
      ),
    ];

    for (final l in layers) {
      canvas.drawArc(
        diskRect,
        front ? 0.0 : math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = l.w
          ..strokeCap = StrokeCap.round
          ..color = (front ? l.cf : l.cb).withOpacity(
              (front ? brightFront : brightBack).clamp(0.0, 1.0)),
      );
    }
  }

  void _drawLensingArcs(Canvas canvas, double cx, double cy, double R) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 위쪽 아크 (황금빛)
    p
      ..strokeWidth = 0.9
      ..color = const Color(0xFFFFE566).withOpacity(0.52);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, cy), width: R * 1.22, height: R * 0.56),
      math.pi * 1.13,
      math.pi * 0.74,
      false,
      p,
    );

    // 아래쪽 아크 (흰빛)
    p
      ..strokeWidth = 0.7
      ..color = Colors.white.withOpacity(0.28);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, cy), width: R * 1.16, height: R * 0.52),
      math.pi * 0.13,
      math.pi * 0.74,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(_BlackholePainter old) =>
      t != old.t || isDark != old.isDark;
}
