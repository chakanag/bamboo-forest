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
    
    // Total duration should probably be based on the initial ttl, 
    // but extensions complicate this. We'll just clamp.
    // However, to show a progress bar, we need a "total" reference.
    // If TTL can increase, the bar might jump back. That's acceptable for this game mechanic.
    // We will assume 'total' is the current TTL seconds + age? No, that's complex.
    // Let's just use the provided ttlSeconds as the "max" context for now, 
    // or maybe hardcode a "standard" 10 min window for visualization if not extended?
    // Better: Just show remaining time text and a bar that represents % of 10 mins (600s)?
    // Or just % of the current total TTL.
    
    if (mounted) {
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
        // Visual hack: Assume max is 10 mins (600s) or the current TTL if larger
        int max = widget.ttlSeconds > 600 ? widget.ttlSeconds : 600;
        _percent = (_remainingSeconds / max).clamp(0.0, 1.0);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Color _getColor() {
    if (_percent > 0.5) return AppTheme.bambooDeep;
    if (_percent > 0.2) return Colors.orange;
    return AppTheme.alertRed;
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '남은 시간',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _formatTime(_remainingSeconds),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearPercentIndicator(
          lineHeight: 6.0,
          percent: _percent,
          backgroundColor: AppTheme.bambooLight,
          progressColor: _getColor(),
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
