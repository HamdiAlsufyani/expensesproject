import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../../core/services/google_drive_service.dart';
import '../../../shared/components/common_widgets.dart';
import '../../../shared/localization_extensions.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _account;
  List<DriveBackupFile> _driveFiles = const [];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreSession);
  }

  Future<void> _restoreSession() async {
    try {
      final drive = ref.read(googleDriveServiceProvider);
      await drive.initialize();
      if (!mounted) return;
      setState(() => _account = drive.signedInEmail);
      if (_account != null) await _loadDriveFiles();
    } catch (_) {
      // Drive remains optional; the local backup system is always available.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.backup)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.safeRestore,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(context.l10n.safeRestoreDescription),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(
          title: context.l10n.localBackup,
          icon: Icons.storage_outlined,
        ),
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.save_alt_outlined,
                title: context.l10n.createBackup,
                subtitle: context.l10n.backupDescription,
                busy: _busy,
                onTap: _createBackup,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.data_object_outlined,
                title: context.l10n.exportJson,
                subtitle: context.l10n.backupDescription,
                busy: _busy,
                onTap: _exportJson,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.file_open_outlined,
                title: context.l10n.importDatabase,
                subtitle: context.l10n.backupFile,
                busy: _busy,
                onTap: _importDatabase,
              ),
              const Divider(height: 1),
              _ActionTile(
                icon: Icons.input_outlined,
                title: context.l10n.importJson,
                subtitle: context.l10n.jsonFile,
                busy: _busy,
                onTap: _importJson,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: context.l10n.googleDrive,
          icon: Icons.cloud_outlined,
        ),
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_account == null) ...[
                Text(
                  context.l10n.driveSetupRequired,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: Text(context.l10n.signInGoogle),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.account_circle_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(context.l10n.signedInAs(_account!))),
                    IconButton(
                      onPressed: _busy ? null : _signOut,
                      tooltip: context.l10n.logout,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _upload,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(context.l10n.uploadBackup),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.availableBackups,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : _loadDriveFiles,
                      tooltip: context.l10n.retry,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (_driveFiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: Text(context.l10n.noData)),
                  )
                else ...[
                  for (final item in _driveFiles)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.backup_outlined),
                      title: Text(item.name),
                      subtitle: item.createdAt == null
                          ? null
                          : Text(context.date(item.createdAt!.toLocal())),
                      trailing: IconButton(
                        onPressed: _busy ? null : () => _restoreDrive(item),
                        tooltip: context.l10n.restoreFromDrive,
                        icon: const Icon(Icons.restore_outlined),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _createBackup() async => _run(() async {
    final backup = await ref.read(backupServiceProvider).createDatabaseBackup();
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(backup.databaseFile.path),
          XFile(backup.manifestFile.path),
        ],
      ),
    );
    if (mounted) showFeedback(context, message: context.l10n.backupCreated);
  });

  Future<void> _exportJson() async => _run(() async {
    final file = await ref.read(backupServiceProvider).exportJson();
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    if (mounted) showFeedback(context, message: context.l10n.exportCompleted);
  });

  Future<void> _importDatabase() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite', 'sqlite3'],
    );
    final path = picked.singleOrNull?.path;
    if (path == null || !mounted) return;
    final confirmed = await confirmDestructiveAction(
      context,
      title: context.l10n.restoreWarningTitle,
      message: context.l10n.restoreWarning,
      cancel: context.l10n.cancel,
      confirm: context.l10n.confirm,
    );
    if (!confirmed) return;
    await _run(() async {
      await ref.read(backupServiceProvider).restoreDatabase(File(path));
      if (mounted) {
        showFeedback(context, message: context.l10n.databaseProtected);
        showFeedback(context, message: context.l10n.restoreCompleted);
      }
    });
  }

  Future<void> _importJson() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.singleOrNull?.path;
    if (path == null) return;
    await _run(() async {
      await ref.read(backupServiceProvider).importJson(File(path));
      if (mounted) showFeedback(context, message: context.l10n.importCompleted);
    });
  }

  Future<void> _signIn() async => _run(() async {
    final email = await ref.read(googleDriveServiceProvider).signIn();
    if (mounted) setState(() => _account = email);
    await _loadDriveFiles();
  });

  Future<void> _signOut() async => _run(() async {
    await ref.read(googleDriveServiceProvider).signOut();
    if (mounted) {
      setState(() {
        _account = null;
        _driveFiles = const [];
      });
    }
  });

  Future<void> _upload() async => _run(() async {
    final artifact = await ref
        .read(backupServiceProvider)
        .createDatabaseBackup();
    await ref
        .read(googleDriveServiceProvider)
        .uploadBackup(artifact.databaseFile);
    if (mounted) showFeedback(context, message: context.l10n.backupUploaded);
    await _loadDriveFiles();
  });

  Future<void> _loadDriveFiles() async {
    try {
      final files = await ref.read(googleDriveServiceProvider).listBackups();
      if (mounted) setState(() => _driveFiles = files);
    } catch (error) {
      if (mounted) {
        showFeedback(
          context,
          message: safeErrorMessage(error, context.l10n),
          error: true,
        );
      }
    }
  }

  Future<void> _restoreDrive(DriveBackupFile remote) async {
    final confirmed = await confirmDestructiveAction(
      context,
      title: context.l10n.restoreWarningTitle,
      message: context.l10n.restoreWarning,
      cancel: context.l10n.cancel,
      confirm: context.l10n.confirm,
    );
    if (!confirmed) return;
    await _run(() async {
      final file = await ref
          .read(googleDriveServiceProvider)
          .downloadBackup(remote);
      await ref.read(backupServiceProvider).restoreDatabase(file);
      if (mounted) {
        showFeedback(context, message: context.l10n.databaseProtected);
        showFeedback(context, message: context.l10n.restoreCompleted);
      }
    });
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (error) {
      if (mounted) {
        showFeedback(
          context,
          message: safeErrorMessage(error, context.l10n),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    enabled: !busy,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: busy ? null : onTap,
  );
}
