import 'dart:async';
import 'package:flutter/material.dart';
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

    // 임종 직전엔 본문 살짝 흐리게 (정적)
    final contentOpacity =
        _healthState == _HealthState.critical ? 0.60 : 1.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 상단 생명력 바 (색상만 변함) ──────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              height: 3,
              color: healthColor,
            ),

            // ── 본문 영역 ─────────────────────────────────────────────────
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
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tagBg,
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: tagText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),

                      // 상태 배지 (fresh 이면 숨김)
                      if (_healthState != _HealthState.fresh) ...[
                        const SizedBox(width: 8),
                        _HealthLabel(
                          state: _healthState,
                          color: healthColor,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 본문
                  Opacity(
                    opacity: contentOpacity,
                    child: Text(
                      widget.post.content,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // TTL 타이머
                  TtlTimer(
                    createdAt: widget.post.createdAt,
                    ttlSeconds: widget.post.ttlSeconds,
                  ),

                  const SizedBox(height: 10),

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
  }
}

// ── 상태 레이블 (정적 — blinking 없음) ──────────────────────────────────────────
class _HealthLabel extends StatelessWidget {
  final _HealthState state;
  final Color color;

  const _HealthLabel({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    final label =
        state == _HealthState.critical ? '임종 직전' : '시들고 있어요';

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
