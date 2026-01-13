import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/post.dart';
import '../theme/app_theme.dart';
import 'ttl_timer.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tags and Timer
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: post.tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.bambooLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Content
              Text(
                post.content,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 16),
              
              // Timer
              TtlTimer(
                createdAt: post.createdAt,
                ttlSeconds: post.ttlSeconds,
              ),
              
              const SizedBox(height: 12),
              
              // Footer: Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildStat(Icons.visibility_outlined, post.views),
                  const SizedBox(width: 16),
                  _buildStat(Icons.favorite_border, post.recommendations),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStat(IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSub),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            color: AppTheme.textSub,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
