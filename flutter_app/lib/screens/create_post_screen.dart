import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/posts_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || content.length > 200) return;

    setState(() => _isSubmitting = true);

    try {
      await ref.read(postsProvider.notifier).addPost(content);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('게시글이 숲에 심어졌습니다.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 글쓰기 배경 — 다크모드는 카드 색, 라이트모드는 흰색
    final fieldBg = isDark ? scheme.surface : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('새 글 쓰기')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLength: 200,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: '임금님 귀는 당나귀 귀...\n하고 싶은 말을 적어보세요.',
                  filled: true,
                  fillColor: fieldBg,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterStyle: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, child) {
                  final text = value.text.trim();
                  final isValid = text.isNotEmpty && text.length <= 200;

                  return ElevatedButton(
                    onPressed: isValid && !_isSubmitting ? _submit : null,
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: scheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '숲에 외치기',
                            style: TextStyle(fontSize: 16),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
