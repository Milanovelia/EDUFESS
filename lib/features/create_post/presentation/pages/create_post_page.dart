import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../feed/data/models/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../providers/create_post_controller.dart';

/// Create post composer — content-first social input.
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
    final theme = Theme.of(context);
    final isLoading = ref.watch(createPostControllerProvider) is AsyncLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.tonal(
              onPressed: isLoading ? null : _handleSubmit,
              child: isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Posting'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: 'Apa yang sedang kamu pikirkan?',
                  border: InputBorder.none,
                ),
                style: theme.textTheme.bodyLarge,
                enabled: !isLoading,
                autofocus: true,
                maxLines: 10,
                minLines: 5,
                maxLength: 10000,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Konten wajib diisi.' : null,
              ),
              const Divider(height: AppSpacing.lg),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul *',
                  hintText: 'Beri judul singkat',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                enabled: !isLoading,
                maxLength: 200,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi.' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final t in PostType.all)
                    ChoiceChip(
                      label: Text(PostType.labels[t]!),
                      selected: _selectedType == t,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: isLoading ? null : (_) => setState(() => _selectedType = t),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  ChoiceChip(
                    label: Text(_isPseudonymous ? 'Anonim' : 'Publik', style: theme.textTheme.labelSmall),
                    selected: _isPseudonymous,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: isLoading ? null : (v) => setState(() => _isPseudonymous = v),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _isPseudonymous ? 'Disamarkan sebagai Siswa Anonim' : 'Tampil sebagai pseudonym kamu',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
