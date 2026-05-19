import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../providers/posts_provider.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'ranking_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// 갤럭시 타임라인
//   다크 모드 → 우주(별·성운·별똥별), 라이트 모드 → 햇살에 부서지는 물방울
// ═══════════════════════════════════════════════════════════════════════════════
class GalaxyTimelineScreen extends ConsumerStatefulWidget {
  const GalaxyTimelineScreen({super.key});

  @override
  ConsumerState<GalaxyTimelineScreen> createState() =>
      _GalaxyTimelineScreenState();
}

class _GalaxyTimelineScreenState extends ConsumerState<GalaxyTimelineScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  // ── 헬스 계산 ─────────────────────────────────────────────────────────────
  static double _health(Post post) {
    if (post.ttlSeconds <= 0) return 0.0;
    final exp = post.createdAt.add(Duration(seconds: post.ttlSeconds));
    final rem = exp.difference(DateTime.now()).inSeconds;
    return (rem / post.ttlSeconds).clamp(0.0, 1.0);
  }

  // ── 버블 위치: 뷰포트 기준 원형 배치 ──────────────────────────────────────
  Offset _bubbleCenter(Post post, Size viewport) {
    final rng = math.Random(post.id.hashCode);
    final angle = rng.nextDouble() * math.pi * 2;
    final h = _health(post);
    final maxR = math.min(viewport.width, viewport.height) * 0.41;
    // 건강할수록 중앙, 만료 임박할수록 가장자리
    final radius = maxR * (0.08 + (1.0 - h) * 0.82);
    return Offset(
      viewport.width / 2 + radius * math.cos(angle),
      viewport.height / 2 + radius * math.sin(angle),
    );
  }

  // 건강할수록 크게 (55~132px)
  static double _bubbleSize(Post post) => 55.0 + _health(post) * 77.0;

  // ── 빌드 ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsAsync = ref.watch(postsProvider);

    // 배경색
    final bgColor = isDark
        ? AppTheme.darkBg      // 우주 보라-검정 #080412
        : AppTheme.surfaceLight; // 연보라 크림 #FAF7FF

    // 로딩/에러 텍스트·아이콘 색
    final accentColor = isDark
        ? AppTheme.darkPrimary   // 달빛 연보라
        : AppTheme.purpleDeep;   // 짙은 보라

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // ── 레이어 1: 배경 애니메이션 ────────────────────────────────────
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => CustomPaint(
                  painter: isDark
                      ? _GalaxyPainter(_bgCtrl.value)
                      : _SunlitPainter(_bgCtrl.value),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // ── 레이어 2: 줌/팬 버블 ─────────────────────────────────────────
          postsAsync.when(
            data: (posts) => LayoutBuilder(
              builder: (context, constraints) {
                final viewport =
                    Size(constraints.maxWidth, constraints.maxHeight);
                return InteractiveViewer(
                  minScale: 0.3,
                  maxScale: 5.0,
                  boundaryMargin: EdgeInsets.all(
                      math.min(viewport.width, viewport.height) * 0.5),
                  child: SizedBox(
                    width: viewport.width,
                    height: viewport.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final post in posts)
                          _buildBubble(post, viewport, isDark),
                      ],
                    ),
                  ),
                );
              },
            ),
            loading: () => Center(
              child: CircularProgressIndicator(color: accentColor),
            ),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: AppTheme.healthRed, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    '$e',
                    style: TextStyle(
                        color: isDark
                            ? AppTheme.darkTextSub
                            : Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        ref.read(postsProvider.notifier).refresh(),
                    child: Text('다시 시도',
                        style: TextStyle(color: accentColor)),
                  ),
                ],
              ),
            ),
          ),

          // ── 레이어 3: 고정 UI 오버레이 ────────────────────────────────────
          SafeArea(child: _buildOverlay(postsAsync)),
        ],
      ),
    );
  }

  Widget _buildBubble(Post post, Size viewport, bool isDark) {
    final center = _bubbleCenter(post, viewport);
    final size = _bubbleSize(post);
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: _PostBubble(
        key: ValueKey(post.id),
        post: post,
        size: size,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: post.id)),
        ),
      ),
    );
  }

  Widget _buildOverlay(AsyncValue<List<Post>> postsAsync) {
    return Stack(
      children: [
        // 로고 — 좌측 상단
        const Positioned(top: 14, left: 16, child: _LogoChip()),

        // 집계 — 우측 상단
        Positioned(
          top: 14,
          right: 16,
          child: postsAsync.whenData((p) => _StatsChip(posts: p)).value ??
              const SizedBox(),
        ),

        // 설정 — 좌측 하단
        Positioned(
          bottom: 28,
          left: 24,
          child: _GlassButton(
            icon: Icons.tune_rounded,
            onTap: () {}, // TODO: 설정 화면
          ),
        ),

        // 등록 — 우측 하단
        Positioned(
          bottom: 28,
          right: 24,
          child: _GlassButton(
            icon: Icons.add_rounded,
            isPrimary: true,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              );
              if (mounted) ref.read(postsProvider.notifier).refresh();
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 다크 모드: 갤럭시 배경 — 별 깜빡임 + 성운 + 별똥별
// ═══════════════════════════════════════════════════════════════════════════════
class _GalaxyPainter extends CustomPainter {
  final double t;
  _GalaxyPainter(this.t);

  static final _rng = math.Random(2048);

  static final _stars = List.generate(240, (_) => (
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        r: _rng.nextDouble() * 1.7 + 0.15,
        a: _rng.nextDouble() * 0.55 + 0.15,
        tw: _rng.nextDouble(),
      ));

  static final _shoots = List.generate(5, (i) => (
        sx: _rng.nextDouble() * 0.7,
        sy: _rng.nextDouble() * 0.4,
        len: _rng.nextDouble() * 0.18 + 0.10,
        angle: math.pi / 4.2 + (_rng.nextDouble() - 0.5) * 0.5,
        phase: i / 5.0,
      ));

  @override
  void paint(Canvas canvas, Size size) {
    _drawNebula(canvas, size);

    final p = Paint();
    for (final s in _stars) {
      final tw = (math.sin((t + s.tw) * math.pi * 5) + 1) / 2;
      p.color = Colors.white.withOpacity(s.a * (0.4 + tw * 0.6));
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, p);
    }

    const window = 0.14;
    for (final ss in _shoots) {
      final local = (t + ss.phase) % 1.0;
      if (local > window) continue;
      final prog = local / window;
      final alpha = math.sin(prog * math.pi);
      final hx = (ss.sx + prog * ss.len * math.cos(ss.angle)) * size.width;
      final hy = (ss.sy + prog * ss.len * math.sin(ss.angle)) * size.height;
      final tx = hx - ss.len * 0.7 * size.width * math.cos(ss.angle);
      final ty = hy - ss.len * 0.7 * size.height * math.sin(ss.angle);
      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              Colors.white.withOpacity(0.0),
              Colors.white.withOpacity(0.8 * alpha),
            ],
          ).createShader(Rect.fromPoints(Offset(tx, ty), Offset(hx, hy))),
      );
      canvas.drawCircle(Offset(hx, hy), 2.4 * alpha,
          Paint()..color = Colors.white.withOpacity(0.95 * alpha));
    }
  }

  void _drawNebula(Canvas canvas, Size size) {
    // 우측 상단 — 짙은 보라 성운 (주성운)
    _radialFog(
      canvas,
      center: Offset(size.width * 0.80, size.height * 0.14),
      radius: size.width * 0.52,
      color: const Color(0xFF3B0764).withOpacity(0.35),
    );
    // 좌측 하단 — 인디고 성운 (보조 성운)
    _radialFog(
      canvas,
      center: Offset(size.width * 0.14, size.height * 0.80),
      radius: size.width * 0.44,
      color: const Color(0xFF1E1B4B).withOpacity(0.30),
    );
    // 중앙 — 연보라빛 핵 (포스트들이 모이는 곳)
    _radialFog(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.5),
      radius: size.width * 0.32,
      color: const Color(0xFF2D1A4A).withOpacity(0.20),
    );
    // 우측 하단 — 마젠타 포인트 성운
    _radialFog(
      canvas,
      center: Offset(size.width * 0.88, size.height * 0.75),
      radius: size.width * 0.28,
      color: const Color(0xFF701A75).withOpacity(0.18),
    );
  }

  void _radialFog(Canvas canvas,
      {required Offset center,
      required double radius,
      required Color color}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GalaxyPainter old) => t != old.t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 라이트 모드: 햇살에 부서지는 물방울 — 분무기처럼 미세한 입자 산란
// ═══════════════════════════════════════════════════════════════════════════════
class _SunlitPainter extends CustomPainter {
  final double t;
  _SunlitPainter(this.t);

  static final _rng = math.Random(4096);

  // 미세 물방울 입자 500개 (분무기 효과)
  static final _mist = List.generate(500, (_) => (
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        r: _rng.nextDouble() * 0.55 + 0.12, // 0.12~0.67px — 매우 작은 입자
        phase: _rng.nextDouble(),            // 깜빡임 위상
        speed: _rng.nextDouble() * 6 + 5,   // 깜빡임 속도 (빠름)
        bright: _rng.nextDouble() * 0.45 + 0.15,
        isGold: _rng.nextDouble() < 0.35,   // 35%는 황금빛, 65%는 흰빛
      ));

  // 약간 더 눈에 띄는 큰 반짝임 30개 (포인트 하이라이트)
  static final _glints = List.generate(30, (_) => (
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        r: _rng.nextDouble() * 0.9 + 0.4,
        phase: _rng.nextDouble(),
        speed: _rng.nextDouble() * 4 + 3,
      ));

  @override
  void paint(Canvas canvas, Size size) {
    _drawLightRays(canvas, size);
    _drawMist(canvas, size);
    _drawGlints(canvas, size);
  }

  // 아주 은은한 햇살 광선 (배경 분위기용)
  void _drawLightRays(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final shimmer = (math.sin(t * math.pi * 2 + i * 1.8) + 1) / 2;
      final alpha = 0.012 + shimmer * 0.012; // 매우 연하게
      final rx = size.width * (0.60 + i * 0.20);

      final path = Path()
        ..moveTo(rx, 0)
        ..lineTo(math.min(rx + size.width * 0.22, size.width), 0)
        ..lineTo(0, size.height)
        ..lineTo(math.max(rx - size.width * 0.28, 0), size.height)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              const Color(0xFFFFE066).withOpacity(alpha),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }
  }

  // 분무기 미세 입자 — 각자 빠르게 깜빡이며 흩뿌려진 느낌
  void _drawMist(Canvas canvas, Size size) {
    final p = Paint();
    for (final s in _mist) {
      final tw = (math.sin((t + s.phase) * math.pi * s.speed) + 1) / 2;
      final alpha = s.bright * tw;
      if (alpha < 0.04) continue;

      p.color = (s.isGold ? const Color(0xFFFFD060) : Colors.white)
          .withOpacity(alpha * 0.70);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        p,
      );
    }
  }

  // 포인트 하이라이트 — 군데군데 살짝 더 밝은 반짝임
  void _drawGlints(Canvas canvas, Size size) {
    final p = Paint();
    for (final g in _glints) {
      final tw = math.pow(
              (math.sin((t + g.phase) * math.pi * g.speed) + 1) / 2, 2.5)
          .toDouble(); // 제곱으로 날카롭게
      final alpha = tw * 0.55;
      if (alpha < 0.08) continue;

      final cx = g.x * size.width;
      final cy = g.y * size.height;

      // 흰빛 코어
      p.color = Colors.white.withOpacity(alpha);
      canvas.drawCircle(Offset(cx, cy), g.r, p);

      // 아주 짧은 십자 광채 (2px 길이)
      final arm = g.r * 1.8 * tw;
      if (arm < 0.5) continue;
      final lp = Paint()
        ..color = Colors.white.withOpacity(alpha * 0.50)
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), lp);
      canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), lp);
    }
  }

  @override
  bool shouldRepaint(_SunlitPainter old) => t != old.t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 포스트 버블
// ═══════════════════════════════════════════════════════════════════════════════
class _PostBubble extends StatefulWidget {
  final Post post;
  final double size;
  final VoidCallback onTap;

  const _PostBubble({
    super.key,
    required this.post,
    required this.size,
    required this.onTap,
  });

  @override
  State<_PostBubble> createState() => _PostBubbleState();
}

class _PostBubbleState extends State<_PostBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    final ms = 1800 + (widget.post.id.hashCode.abs() % 2400);
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  double get _health {
    if (widget.post.ttlSeconds <= 0) return 0.0;
    final exp =
        widget.post.createdAt.add(Duration(seconds: widget.post.ttlSeconds));
    return (exp.difference(DateTime.now()).inSeconds / widget.post.ttlSeconds)
        .clamp(0.0, 1.0);
  }

  // 다크: 연보라·황금·빨강 / 라이트: 중보라·황금·코랄
  Color _glow(double h, bool isDark) {
    if (isDark) {
      if (h > 0.5) return AppTheme.darkPrimary;    // 달빛 연보라
      if (h > 0.2) return AppTheme.healthOrange;   // 황금 주황
      return AppTheme.healthRed;                    // 빨강
    } else {
      if (h > 0.5) return AppTheme.purpleMedium;   // 중간 보라 #8B5CF6
      if (h > 0.2) return const Color(0xFFF59E0B); // 황금빛 앰버
      return const Color(0xFFEF4444);               // 코랄 레드
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h = _health;
    final glow = _glow(h, isDark);
    final opacity = (0.40 + h * 0.60).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final pulse = 1.0 + _pulse.value * 0.048 * h;

        // 라이트 모드 물방울: 더 밝고 굴절이 강함
        final gradientColors = isDark
            ? [
                Colors.white.withOpacity(0.28),
                glow.withOpacity(0.16),
                glow.withOpacity(0.05),
              ]
            : [
                Colors.white.withOpacity(0.82), // 강한 하이라이트
                glow.withOpacity(0.28),
                glow.withOpacity(0.06),
              ];

        final textColor = isDark
            ? Colors.white.withOpacity(0.90)
            : const Color(0xFF1E3A4A).withOpacity(0.85);

        final textShadows = isDark
            ? const [Shadow(color: Color(0xCC000000), blurRadius: 6)]
            : <Shadow>[
                Shadow(
                    color: Colors.white.withOpacity(0.7), blurRadius: 4),
              ];

        return GestureDetector(
          onTap: widget.onTap,
          child: Transform.scale(
            scale: pulse,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.30, -0.35),
                    radius: 0.90,
                    colors: gradientColors,
                    stops: const [0.0, 0.40, 1.0],
                  ),
                  border: Border.all(
                    color: isDark
                        ? glow.withOpacity(0.55)
                        : glow.withOpacity(0.45),
                    width: 1.1,
                  ),
                  boxShadow: [
                    // 외부 글로우
                    BoxShadow(
                      color: glow.withOpacity(isDark ? 0.32 * h : 0.25 * h),
                      blurRadius: widget.size * 0.40,
                      spreadRadius: widget.size * 0.04,
                    ),
                    // 내부 반사광 (라이트에서 더 강함)
                    BoxShadow(
                      color: Colors.white.withOpacity(isDark ? 0.05 : 0.45),
                      blurRadius: widget.size * 0.12,
                      offset: Offset(
                          -widget.size * 0.10, -widget.size * 0.10),
                    ),
                  ],
                ),
                child: widget.size >= 68
                    ? ClipOval(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(widget.size * 0.13),
                            child: Text(
                              widget.post.content,
                              textAlign: TextAlign.center,
                              maxLines: widget.size > 100 ? 4 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: widget.size > 102 ? 11.5 : 9.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                shadows: textShadows,
                              ),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UI 오버레이 위젯
// ═══════════════════════════════════════════════════════════════════════════════

// 유리 컨테이너 — 다크: 검은 유리 / 라이트: 흰 유리
Widget _glass(BuildContext context, {required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: isDark
          ? Colors.white.withOpacity(0.07)
          : Colors.white.withOpacity(0.78),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.90),
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.35)
              : Colors.black.withOpacity(0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

// 로고 칩 — 블랙홀 아이콘
class _LogoChip extends StatefulWidget {
  const _LogoChip();
  @override
  State<_LogoChip> createState() => _LogoChipState();
}

class _LogoChipState extends State<_LogoChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    // 원반이 천천히 반짝이는 8초 주기
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _glass(
      context,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          size: const Size(30, 30),
          painter: _BlackholePainter(_anim.value, isDark),
        ),
      ),
    );
  }
}

// ── 블랙홀 CustomPainter ──────────────────────────────────────────────────────
class _BlackholePainter extends CustomPainter {
  final double t;   // 0.0 ~ 1.0 반복
  final bool isDark;
  _BlackholePainter(this.t, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final R = size.width / 2 - 0.5;

    // ① 바깥 헤일로 — 보라빛 발광, 맥박처럼 천천히 팽창
    final halo = 0.14 + math.sin(t * math.pi * 2) * 0.07;
    canvas.drawCircle(
      Offset(cx, cy), R,
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

    // ② 강착원반 뒷면 (사건지평선 뒤)
    _drawDisk(canvas, cx, cy, R, front: false);

    // ③ 사건지평선 — 순수 검정
    canvas.drawCircle(Offset(cx, cy), R * 0.37, Paint()..color = Colors.black);

    // ④ 광자구 링 (photon ring) — 백색+보라 글로우
    canvas.drawCircle(
      Offset(cx, cy), R * 0.43,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.62)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawCircle(
      Offset(cx, cy), R * 0.47,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFFC084FC).withOpacity(0.42),
    );

    // ⑤ 강착원반 앞면 (사건지평선 앞)
    _drawDisk(canvas, cx, cy, R, front: true);

    // ⑥ 중력렌즈 아크 (블랙홀 뒤편 빛이 휘어 보임)
    _drawLensingArcs(canvas, cx, cy, R);
  }

  // 강착원반 — 앞/뒷면 분리 렌더링으로 입체감 연출
  void _drawDisk(Canvas canvas, double cx, double cy, double R,
      {required bool front}) {
    final diskRect = Rect.fromCenter(
      center: Offset(cx, cy + R * 0.06), // 살짝 아래 — 기울기 표현
      width: R * 1.68,
      height: R * 0.50,
    );

    // 원반 밝기 핫스팟이 천천히 이동 (t 기반)
    final hotspot = t * math.pi * 2;
    final brightFront = 0.70 + 0.25 * math.sin(hotspot).abs();
    final brightBack  = 0.26 + 0.10 * math.cos(hotspot).abs();

    // 레이어 3겹: 골드 코어 → 오렌지 → 보라 외곽
    final layers = <({double w, Color cf, Color cb})>[
      (w: R * 0.17, cf: const Color(0xFFFFE566), cb: const Color(0xFFCC8800)),
      (w: R * 0.11, cf: const Color(0xFFF97316), cb: const Color(0xFFAA4400)),
      (w: R * 0.07, cf: const Color(0xFFC084FC), cb: const Color(0xFF7C3AED)),
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
          ..color = (front ? l.cf : l.cb)
              .withOpacity((front ? brightFront : brightBack).clamp(0.0, 1.0)),
      );
    }
  }

  // 중력렌즈 아크 — 원반 빛이 블랙홀 위/아래로 휘어 보이는 효과
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
      math.pi * 1.13, math.pi * 0.74, false, p);

    // 아래쪽 아크 (흰빛, 약하게)
    p
      ..strokeWidth = 0.7
      ..color = Colors.white.withOpacity(0.28);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(cx, cy), width: R * 1.16, height: R * 0.52),
      math.pi * 0.13, math.pi * 0.74, false, p);
  }

  @override
  bool shouldRepaint(_BlackholePainter old) => t != old.t || isDark != old.isDark;
}

// 집계 칩 (탭 → 랭킹)
class _StatsChip extends StatelessWidget {
  final List<Post> posts;
  const _StatsChip({required this.posts});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary =
        isDark ? AppTheme.darkPrimary : AppTheme.purpleDeep;
    final textColor =
        isDark ? AppTheme.darkTextMain : AppTheme.textMain;
    final active = posts.where((p) => p.status == 'active').length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RankingScreen()),
      ),
      child: _glass(
        context,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bubble_chart_outlined, color: primary, size: 15),
            const SizedBox(width: 5),
            Text(
              '$active 개 떠있음',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 하단 원형 버튼
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppTheme.darkPrimary : AppTheme.purpleDeep;

    final bgColor = isPrimary
        ? primaryColor
        : (isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white.withOpacity(0.82));

    final borderColor = isPrimary
        ? Colors.transparent
        : (isDark
            ? Colors.white.withOpacity(0.18)
            : Colors.white.withOpacity(0.90));

    final iconColor = isPrimary
        ? (isDark ? AppTheme.darkBg : Colors.white)
        : (isDark
            ? Colors.white.withOpacity(0.85)
            : const Color(0xFF2D5566).withOpacity(0.80));

    final shadowColor = isPrimary
        ? primaryColor.withOpacity(0.50)
        : (isDark
            ? Colors.black.withOpacity(0.30)
            : Colors.black.withOpacity(0.12));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: isPrimary ? 22 : 10,
              spreadRadius: isPrimary ? 2 : 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 23),
      ),
    );
  }
}
