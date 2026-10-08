import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../feed/data/models/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../providers/create_post_controller.dart';

/// Create post form — replaces M0 placeholder.
class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPseudonymous = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tipe post.')));
      return;
    }
    final controller = ref.read(createPostControllerProvider.notifier);
    final error = await controller.createPost(
      type: _selectedType!,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      subjectId: null,
      topicId: null,
      isPseudonymous: _isPseudonymous,
    );

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // Success: clear form, refresh feed, go home
    _titleController.clear();
    _contentController.clear();
    setState(() {
      _selectedType = null;
      _isPseudonymous = false;
    });
    ref.invalidate(feedPostsProvider);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post berhasil dibuat.')));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createPostControllerProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Buat Post')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'Tipe Post *', border: OutlineInputBorder()),
              items: PostType.all.map((t) => DropdownMenuItem(value: t, child: Text(PostType.labels[t]!))).toList(),
              onChanged: isLoading ? null : (v) => setState(() => _selectedType = v),
              validator: (v) => v == null ? 'Wajib pilih tipe.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Judul *', border: OutlineInputBorder()),
              enabled: !isLoading,
              maxLength: 200,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Konten *', border: OutlineInputBorder()),
              enabled: !isLoading,
              maxLines: 6,
              maxLength: 10000,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Konten wajib diisi.' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<bool>(
              initialValue: _isPseudonymous,
              decoration: const InputDecoration(labelText: 'Post sebagai', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: false, child: Text('Publik (tampilkan pseudonym)')),
                DropdownMenuItem(value: true, child: Text('Pseudonymous (Siswa Anonim)')),
              ],
              onChanged: isLoading ? null : (v) => setState(() => _isPseudonymous = v ?? false),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: isLoading ? null : _handleSubmit,
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Posting'),
            ),
          ],
        ),
      ),
    );
  }
}
