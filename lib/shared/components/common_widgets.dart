import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../l10n/app_localizations.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return SectionCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: effectiveColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

class AsyncDataView<T> extends StatelessWidget {
  const AsyncDataView({
    super.key,
    required this.value,
    required this.data,
    required this.loadingLabel,
    required this.emptyLabel,
  });
  final AsyncSnapshot<T> value;
  final Widget Function(T value) data;
  final String loadingLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (value.connectionState != ConnectionState.done) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(loadingLabel),
          ],
        ),
      );
    }
    if (value.hasError) {
      return EmptyState(message: emptyLabel, icon: Icons.error_outline);
    }
    return data(value.data as T);
  }
}

Future<bool> confirmDestructiveAction(
  BuildContext context, {
  required String title,
  required String message,
  required String cancel,
  required String confirm,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirm),
            ),
          ],
        ),
      ) ??
      false;
}

void showFeedback(
  BuildContext context, {
  required String message,
  bool error = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      content: Text(message),
    ),
  );
}

String safeErrorMessage(Object error, AppLocalizations l10n) {
  if (error is ValidationException) {
    return switch (error.code) {
      'partyNameRequired' ||
      'descriptionRequired' ||
      'categoryNameRequired' ||
      'partyRequired' => l10n.requiredField,
      'invalidEmail' => l10n.invalidEmail,
      'amountInvalid' => l10n.invalidAmount,
      'partyHasTransactions' => l10n.cannotDeleteParty,
      _ => l10n.operationFailed,
    };
  }
  if (error is BackupException) {
    return error.code == 'invalidBackup'
        ? l10n.invalidBackup
        : l10n.operationFailed;
  }
  return l10n.operationFailed;
}
