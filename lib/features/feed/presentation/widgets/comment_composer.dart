import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';

/// Composer for comment / reply with pseudonymous option.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    required this.onSubmit,
    this.replyToName,
    this.onCancelReply,
    super.key,
  });

  final Future<String?> Function(String content, bool isPseudonymous) onSubmit;
  final String? replyToName;
  final VoidCallback? onCancelReply;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  bool _isPseudonymous = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Komentar wajib diisi.')));
      return;
    }
    setState(() => _loading = true);
    final err = await widget.onSubmit(text, _isPseudonymous);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _controller.clear();
    setState(() => _isPseudonymous = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToName != null)
            Row(
              children: [
                Text('Membalas ${widget.replyToName}', style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                TextButton(onPressed: widget.onCancelReply, child: const Text('Batal')),
              ],
            ),
          TextField(
            controller: _controller,
            enabled: !_loading,
            decoration: const InputDecoration(
              hintText: 'Tulis komentar...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 3,
            minLines: 1,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              DropdownButton<bool>(
                value: _isPseudonymous,
                items: const [
                  DropdownMenuItem(value: false, child: Text('Publik')),
                  DropdownMenuItem(value: true, child: Text('Anonim')),
                ],
                onChanged: _loading ? null : (v) => setState(() => _isPseudonymous = v ?? false),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _handleSend,
                child: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kirim'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
