import 'dart:async';
import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../theme/app_theme.dart';

class TtlTimer extends StatefulWidget {
  final DateTime createdAt;
  final int ttlSeconds;

  const TtlTimer({
    super.key,
    required this.createdAt,
    required this.ttlSeconds,
  });

  @override
  State<TtlTimer> createState() => _TtlTimerState();
}

class _TtlTimerState extends State<TtlTimer> {
  late Timer _timer;
  late int _remainingSeconds;
  late double _percent;
  // API에서 받은 ttl_seconds는 '현재 남은 시간'이므로
  // 위젯 초기화 시점 기준으로 만료 시각을 고정한다.
  late final DateTime _expireTime;
  static const int _defaultTtl = 600; // 기준 총 TTL (초)

  @override
  void initState() {
    super.initState();
    _expireTime = DateTime.now().add(Duration(seconds: widget.ttlSeconds));
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  void _calculateTime() {
    final now = DateTime.now();
    final diff = _expireTime.difference(now).inSeconds;
    // 총 기준: ttlSeconds가 기본보다 길면(추천으로 연장된 경우) 그걸 기준으로
    final total = widget.ttlSeconds > _defaultTtl ? widget.ttlSeconds : _defaultTtl;

    if (mounted) {
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
        _percent = (_remainingSeconds / total).clamp(0.0, 1.0);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// 건강 상태에 따라 색상 반환 — context로 테마 감지
  Color _getColor(BuildContext context) {
    if (_percent > 0.5) return Theme.of(context).colorScheme.primary;
    if (_percent > 0.2) return AppTheme.healthOrange;
    return AppTheme.healthRed;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = Theme.of(context).textTheme.bodySmall?.color;
    final barBg = isDark
        ? AppTheme.darkBorder
        : AppTheme.purpleLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '사라지기까지',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: labelColor,
              ),
            ),
            Text(
              _formatTime(_remainingSeconds),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearPercentIndicator(
          lineHeight: 6.0,
          percent: _percent,
          backgroundColor: barBg,
          progressColor: color,
          barRadius: const Radius.circular(3),
          padding: EdgeInsets.zero,
          animation: true,
          animateFromLastPercent: true,
          animationDuration: 1000,
        ),
      ],
    );
  }
}
