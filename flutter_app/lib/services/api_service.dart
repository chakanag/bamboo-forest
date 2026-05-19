import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/post.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    // Android Emulator requires 10.0.2.2 to access host localhost
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    // iOS Simulator and others use localhost
    return 'http://localhost:8000';
  }

  Future<List<Post>> getPosts() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/posts/'));

    if (response.statusCode == 200) {
      // 서버 응답: { "posts": [...], "total": N, "page": N, "per_page": N }
      final Map<String, dynamic> body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final List<dynamic> posts = body['posts'] as List<dynamic>;
      return posts.map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
  }

  Future<Post> createPost(String content) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/posts/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'content': content}),
    );

    // 서버가 201 Created 반환
    if (response.statusCode == 201) {
      return Post.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to create post: ${response.body}');
    }
  }

  Future<Post> getPost(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/posts/$id'));

    if (response.statusCode == 200) {
      return Post.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
    } else {
      throw Exception('Failed to load post: ${response.statusCode}');
    }
  }

  Future<bool> recommendPost(String id) async {
    final response = await http.post(Uri.parse('$baseUrl/api/v1/posts/$id/recommend'));
    return response.statusCode == 200;
  }

  Future<bool> reportPost(String id) async {
    final response = await http.post(Uri.parse('$baseUrl/api/v1/posts/$id/report'));
    return response.statusCode == 200;
  }

  Future<List<Post>> getRanking(String type) async {
    // type: 'views' or 'recs'
    // 서버 응답: List<PostResponse> (직접 배열)
    final response =
        await http.get(Uri.parse('$baseUrl/api/v1/posts/ranking/$type'));

    if (response.statusCode == 200) {
      final List<dynamic> body =
          jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return body
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load ranking');
    }
  }
}
