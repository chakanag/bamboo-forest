import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/post.dart';
import '../theme/app_theme.dart';
import 'ttl_timer.dart';

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

class _PostCardState extends State<PostCard> {
  late Timer _timer;
  double _healthPercent = 1.0;

  @override
  void initState() {
    super.initState();
    _updateHealth();
    // 5초마다 갱신 (TtlTimer가 1초 단위로 이미 돌고 있으므로 카드 수준은 여유롭게)
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _updateHealth());
  }

  void _updateHealth() {
    final expireAt =
        widget.post.createdAt.add(Duration(seconds: widget.post.ttlSeconds));
    final remaining = expireAt.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() {
        _healthPercent =
            (remaining / widget.post.ttlSeconds).clamp(0.0, 1.0);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ── 상태 계산 ──────────────────────────────────────────────────────────────
  _HealthState get _healthState {
    if (_healthPercent > 0.5) return _HealthState.fresh;
    if (_healthPercent > 0.2) return _HealthState.fading;
    return _HealthState.critical;
  }

  /// fresh 상태는 테마의 primary 색상 사용 → 라이트/다크 모두 자동 대응
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

  double get _cardOpacity {
    switch (_healthState) {
      case _HealthState.fresh:
        return 1.0;
      case _HealthState.fading:
        return 0.88;
      case _HealthState.critical:
        return 0.70;
    }
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textMain = scheme.onSurface;
    final textSub = scheme.onSurface.withOpacity(0.55);

    // 태그 칩 색상 — 다크모드는 배경을 subtle하게
    final tagBg = isDark
        ? scheme.onSurface.withOpacity(0.10)
        : AppTheme.purpleLight;
    final tagText = scheme.primary;

    final healthColor = _healthColor(context);

    // 임종 직전엔 본문도 흐리게
    final contentColor = _healthState == _HealthState.critical
        ? textMain.withOpacity(0.65)
        : textMain;

    return AnimatedOpacity(
      opacity: _cardOpacity,
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      child: Card(
        // 상단 헬스바 클리핑을 위해 antiAlias 설정
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 상단 생명력 바 ──────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                height: 3,
                color: healthColor,
              ),

              // ── 본문 영역 ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더: 태그 + 상태 배지
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: tagText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),

                        // 상태 배지 — fresh일 때는 숨김 (깔끔하게)
                        if (_healthState != _HealthState.fresh) ...[
                          const SizedBox(width: 8),
                          _HealthBadge(
                            state: _healthState,
                            color: healthColor,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 본문
                    Text(
                      widget.post.content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: contentColor,
                          ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    // TTL 타이머
                    TtlTimer(
                      createdAt: widget.post.createdAt,
                      ttlSeconds: widget.post.ttlSeconds,
                    ),

                    const SizedBox(height: 12),

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
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

// ── 생명 상태 배지 ─────────────────────────────────────────────────────────────
class _HealthBadge extends StatelessWidget {
  final _HealthState state;
  final Color color;

  const _HealthBadge({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    final label =
        state == _HealthState.critical ? '임종 직전' : '시들고 있어요';

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 상태 점
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
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

    // 임종 직전엔 점이 깜빡임
    if (state == _HealthState.critical) {
      return badge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(begin: 0.4, duration: 900.ms, curve: Curves.easeInOut);
    }

    return badge;
  }
}

// ── 통계 칩 ────────────────────────────────────────────────────────────────────
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
