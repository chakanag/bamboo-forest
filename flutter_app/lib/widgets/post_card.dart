import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../theme/app_theme.dart';

// ── 생명 상태 ─────────────────────────────────────────────────────────────────
enum _HealthState { fresh, fading, critical }

// ── PostCard ──────────────────────────────────────────────────────────────────
class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  late Timer _healthTimer;
  double _healthPercent = 1.0;

  // API ttl_seconds = 현재 남은 시간 → 초기화 시점 기준으로 만료 시각 고정
  late final DateTime _expireAt;
  static const int _defaultTtl = 600;

  // 먼지 해체 애니메이션
  late final AnimationController _dissolveCtrl;
  bool _dissolving = false;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _expireAt = DateTime.now().add(Duration(seconds: widget.post.ttlSeconds));
    _particles = List.generate(24, (_) => _Particle.random());

    _dissolveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _updateHealth();
    _healthTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _updateHealth());
  }

  void _updateHealth() {
    final remaining = _expireAt.difference(DateTime.now()).inSeconds;
    final total = widget.post.ttlSeconds > _defaultTtl
        ? widget.post.ttlSeconds
        : _defaultTtl;
    if (!mounted) return;
    final pct = (remaining / total).clamp(0.0, 1.0);
    setState(() => _healthPercent = pct);

    if (pct == 0.0 && !_dissolving) {
      _dissolving = true;
      _dissolveCtrl.forward();
    }
  }

  @override
  void dispose() {
    _healthTimer.cancel();
    _dissolveCtrl.dispose();
    super.dispose();
  }

  _HealthState get _healthState {
    if (_healthPercent > 0.5) return _HealthState.fresh;
    if (_healthPercent > 0.2) return _HealthState.fading;
    return _HealthState.critical;
  }

  Color _healthColor(BuildContext context) {
    switch (_healthState) {
      case _HealthState.fresh:
        return Theme.of(context).colorScheme.primary;
      case _HealthState.fading:
        return AppTheme.healthOrange;
      case _HealthState.critical:
        return AppTheme.healthRed;
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSub = scheme.onSurface.withOpacity(0.45);
    final tagBg = isDark
        ? scheme.onSurface.withOpacity(0.08)
        : AppTheme.purpleLight;
    final tagText = scheme.primary;
    final healthColor = _healthColor(context);

    // 건강도에 따라 점진적으로 흐려짐: 1.0 → 0.45
    final cardOpacity = (_healthPercent * 0.55 + 0.45).clamp(0.0, 1.0);
    // 건강도가 낮을수록 블러 증가: 0 → 1.2px
    final blurAmount = ((1.0 - _healthPercent) * 1.2).clamp(0.0, 1.2);

    Widget card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 생명력 색상 바
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              height: 3,
              color: healthColor,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 태그 + 상태 배지
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: widget.post.tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tagBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tagText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (_healthState != _HealthState.fresh) ...[
                        const SizedBox(width: 8),
                        _HealthLabel(
                            state: _healthState, color: healthColor),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    widget.post.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14),

                  // 하단 통계
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _StatChip(
                        icon: Icons.visibility_outlined,
                        count: widget.post.views,
                        color: textSub,
                      ),
                      const SizedBox(width: 16),
                      _StatChip(
                        icon: Icons.favorite_border,
                        count: widget.post.recommendations,
                        color: textSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // 블러 적용 (건강도 낮을 때)
    if (blurAmount > 0.15) {
      card = ImageFiltered(
        imageFilter:
            ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: card,
      );
    }

    // 불투명도 적용
    card = Opacity(opacity: cardOpacity, child: card);

    // 먼지 해체 오버레이
    if (_dissolving) {
      return AnimatedBuilder(
        animation: _dissolveCtrl,
        builder: (context, _) {
          return Stack(
            children: [
              Opacity(
                opacity: (1.0 - _dissolveCtrl.value).clamp(0.0, 1.0),
                child: card,
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DustPainter(
                      progress: _dissolveCtrl.value,
                      particles: _particles,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return card;
  }
}

// ── 파티클 데이터 ──────────────────────────────────────────────────────────────
class _Particle {
  final double x; // 상대 위치 0~1
  final double y;
  final double vx; // 분산 방향
  final double vy;
  final double size;
  final double opacity;

  const _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
  });

  factory _Particle.random() {
    final rng = math.Random();
    final angle = rng.nextDouble() * math.pi * 2;
    final speed = 0.25 + rng.nextDouble() * 0.75;
    return _Particle(
      x: 0.05 + rng.nextDouble() * 0.90,
      y: 0.10 + rng.nextDouble() * 0.80,
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed - 0.25, // 살짝 위로 뜨는 경향
      size: 1.2 + rng.nextDouble() * 2.8,
      opacity: 0.35 + rng.nextDouble() * 0.65,
    );
  }
}

// ── 먼지 파티클 페인터 ────────────────────────────────────────────────────────
class _DustPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final Color color;

  const _DustPainter({
    required this.progress,
    required this.particles,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOut.transform(progress);

    for (final p in particles) {
      final dx = p.x * size.width + p.vx * ease * size.width * 0.45;
      final dy = p.y * size.height + p.vy * ease * size.height * 0.55;
      final alpha = (p.opacity * (1.0 - ease)).clamp(0.0, 1.0);
      if (alpha <= 0.01) continue;

      final paint = Paint()
        ..color = color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(dx, dy),
        p.size * (1.0 - progress * 0.4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.progress != progress;
}

// ── 상태 레이블 ───────────────────────────────────────────────────────────────
class _HealthLabel extends StatelessWidget {
  final _HealthState state;
  final Color color;

  const _HealthLabel({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    final label =
        state == _HealthState.critical ? '곧 사라져요' : '희미해지는 중';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 통계 칩 ───────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(color: color, fontSize: 11),
        ),
      ],
    );
  }
}
