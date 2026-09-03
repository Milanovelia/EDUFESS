import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/moderation_providers.dart';
import '../../data/models/moderation_report.dart';

/// Shows report dialog for post or comment.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType, // post|comment
  String? postId,
  String? commentId,
}) async {
  final formKey = GlobalKey<FormState>();
  String? selectedReason;
  final detailsCtrl = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(targetType == 'post' ? 'Laporkan Post' : 'Laporkan Komentar'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder()),
                items: ReportReason.all
                    .map((r) => DropdownMenuItem(value: r, child: Text(ReportReason.labels[r]!)))
                    .toList(),
                onChanged: (v) => selectedReason = v,
                validator: (v) => v == null ? 'Pilih alasan.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: detailsCtrl,
                decoration: const InputDecoration(labelText: 'Detail (opsional)', border: OutlineInputBorder(), hintText: 'Jelaskan jika perlu'),
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        Consumer(builder: (context, ref2, _) {
          final loading = ref2.watch(reportControllerProvider).isLoading;
          return FilledButton(
            onPressed: loading
                ? null
                : () async {
                    if (!formKey.currentState!.validate()) return;
                    String? err;
                    if (targetType == 'post') {
                      err = await ref.read(reportControllerProvider.notifier).reportPost(
                            postId: postId!,
                            reason: selectedReason!,
                            details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
                          );
                    } else {
                      err = await ref.read(reportControllerProvider.notifier).reportComment(
                            commentId: commentId!,
                            reason: selectedReason!,
                            details: detailsCtrl.text.trim().isEmpty ? null : detailsCtrl.text.trim(),
                          );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan berhasil dikirim.')));
                    }
                  },
            child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kirim'),
          );
        }),
      ],
    ),
  );
}
