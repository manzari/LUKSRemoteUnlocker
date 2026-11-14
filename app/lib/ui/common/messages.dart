import 'package:material_ui/material_ui.dart';
import 'package:unlock_core/unlock_core.dart';

import '../../data/errors.dart';

/// User-facing text for an error; never includes secret material.
String describeError(Object error) => switch (error) {
  DataException(:final message) => message,
  VaultWrongPasswordException() => 'Wrong password.',
  VaultLockedException() => 'The vault is locked. Unlock it and try again.',
  VaultKeyInvalidatedException() =>
    'Biometric unlock stopped working because the fingerprints or face on '
        'this device changed. Use the recovery password.',
  VaultKeyUnavailableException(
    reason: VaultKeyUnavailableReason.userCancelled,
  ) =>
    'Cancelled.',
  VaultKeyUnavailableException(reason: VaultKeyUnavailableReason.lockedOut) =>
    'Too many attempts. Try again later or use the password.',
  VaultKeyUnavailableException() =>
    'Biometric unlock is not available right now.',
  VaultNoSlotException(:final message) => 'Not possible: $message.',
  VaultException(:final message) => 'Vault error: $message.',
  SshKeyException(:final message) => message,
  FormatException(:final message) => message,
  _ => 'Something went wrong.',
};

bool isCancellation(Object error) =>
    error is VaultKeyUnavailableException &&
    error.reason == VaultKeyUnavailableReason.userCancelled;

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> inform(
  BuildContext context, {
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (subtitle case final s?) Text(s, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
