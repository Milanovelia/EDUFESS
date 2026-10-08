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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Membalas ${widget.replyToName}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onCancelReply,
                    borderRadius: BorderRadius.circular(16),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    hintText: 'Tulis komentar...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton.filledTonal(
                tooltip: 'Kirim komentar',
                onPressed: _loading ? null : _handleSend,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              ChoiceChip(
                label: Text(_isPseudonymous ? 'Anonim' : 'Publik', style: theme.textTheme.labelSmall),
                selected: _isPseudonymous,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _isPseudonymous = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
