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

  @override
  void initState() {
    super.initState();
    _calculateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateTime();
    });
  }

  void _calculateTime() {
    final now = DateTime.now();
    final expireTime = widget.createdAt.add(Duration(seconds: widget.ttlSeconds));
    final diff = expireTime.difference(now).inSeconds;

    if (mounted) {
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
        // 현재 TTL이 기본(600s)보다 크면 그걸 max로, 아니면 600s 기준
        final max = widget.ttlSeconds > 600 ? widget.ttlSeconds : 600;
        _percent = (_remainingSeconds / max).clamp(0.0, 1.0);
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
              '남은 시간',
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
