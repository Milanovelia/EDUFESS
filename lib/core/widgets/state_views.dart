import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';

/// Centered empty-state with a quiet icon, title, and optional supporting text.
///
/// Deliberately compact: state views support the content around them rather
/// than replacing it with a large illustration.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = this.message;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered error-state with a consistent retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.message,
    this.title = 'Terjadi kesalahan',
    this.onRetry,
    this.retryLabel = 'Coba lagi',
    super.key,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.error_outline,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonal(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              ),
              child: Text(retryLabel),
            ),
    );
  }
}

/// Wraps a state view in a scrollable so pull-to-refresh also works when
/// there is no list content to scroll.
class RefreshableStateView extends StatelessWidget {
  const RefreshableStateView({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
