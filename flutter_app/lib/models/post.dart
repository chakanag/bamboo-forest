class Post {
  final String id;
  final String content;
  final DateTime createdAt;
  final int ttlSeconds;
  final List<String> tags;
  final int views;
  final int recommendations;
  final int reports;
  final String status;

  Post({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.ttlSeconds,
    required this.tags,
    required this.views,
    required this.recommendations,
    required this.reports,
    required this.status,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      ttlSeconds: json['ttl_seconds'] as int,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      views: json['views'] as int? ?? 0,
      recommendations: json['recommendations'] as int? ?? 0,
      reports: json['reports'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'ttl_seconds': ttlSeconds,
      'tags': tags,
      'views': views,
      'recommendations': recommendations,
      'reports': reports,
      'status': status,
    };
  }
}
