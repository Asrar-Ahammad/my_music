import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/services/file_scanner_service.dart';
import '../providers/equalizer_provider.dart';
import '../providers/library_provider.dart';
import 'retro_badge.dart';
import 'retro_button.dart';
import 'retro_icon.dart';
import 'retro_toast.dart';

class ScanOptionsDialog extends ConsumerStatefulWidget {
  const ScanOptionsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ScanOptionsDialog(),
    );
  }

  @override
  ConsumerState<ScanOptionsDialog> createState() => _ScanOptionsDialogState();
}

class _ScanOptionsDialogState extends ConsumerState<ScanOptionsDialog> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final settingsRepo = ref.read(settingsRepositoryProvider);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      title: Row(
        children: [
          RetroIcon('folder', size: 20, color: theme.colorScheme.onSurface),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'IMPORT LOCAL MUSIC',
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // Option 1: Select Specific Music Folder
                _buildOptionButton(
                  title: 'SELECT MUSIC FOLDER',
                  subtitle: 'Choose a specific folder from device storage',
                  badge: 'RECOMMENDED',
                  badgeColor: retro.accentGreen,
                  icon: 'folder',
                  iconBg: retro.accentGreen,
                  iconColor: Colors.black,
                  onPressed: () async {
                    try {
                      await PermissionHelper.requestStoragePermission();
                    } catch (_) {}

                    try {
                      final picked = await FilePickerPlatform.instance.getDirectoryPath();
                      if (picked != null && picked.isNotEmpty) {
                        final normalized = FileScannerService.normalizeFolderPath(picked);
                        await settingsRepo.addScanFolder(normalized);
                        await libraryNotifier.loadLibrary();
                        final total = ref.read(libraryProvider).allSongs.length;
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          RetroToast.show(
                            context,
                            'ADDED: ${normalized.split('/').last} ($total TOTAL TRACKS)',
                            icon: 'folder',
                            iconColor: theme.colorScheme.secondary,
                          );
                        }
                      }
                    } catch (e) {
                      setState(() => _status = 'Folder picker note: $e');
                    }
                  },
                ),

                const SizedBox(height: 10),

                // Option 2: Select Audio Files directly (No permissions needed)
                _buildOptionButton(
                  title: 'SELECT AUDIO FILES',
                  subtitle: 'Pick FLAC, MP3, WAV files directly',
                  badge: 'FILES',
                  badgeColor: theme.colorScheme.primary,
                  icon: 'plus',
                  iconBg: theme.colorScheme.primary,
                  iconColor: Colors.white,
                  onPressed: () async {
                    try {
                      final files = await FilePickerPlatform.instance.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'],
                      );

                      if (files.isNotEmpty) {
                        final validPaths = files.map((f) => f.path).whereType<String>().toList();
                        if (validPaths.isNotEmpty) {
                          await libraryNotifier.addCustomAudioFiles(validPaths);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            RetroToast.show(
                              context,
                              'IMPORTED ${validPaths.length} AUDIO FILES',
                              icon: 'music',
                              iconColor: theme.colorScheme.primary,
                            );
                          }
                        }
                      }
                    } catch (e) {
                      setState(() => _status = 'File picker note: $e');
                    }
                  },
                ),

                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red, width: 1.5),
                    ),
                    child: Text(
                      _status,
                      style: RetroTypography.retroMono(color: theme.colorScheme.onSurface, fontSize: 13),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
      actions: [
        RetroButton(
          isCompact: true,
          label: 'CANCEL',
          backgroundColor: retro.cardColor,
          textColor: theme.colorScheme.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required String icon,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: retro.cardColor,
          border: Border.all(
            color: retro.borderColor,
            width: 2.5,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                border: Border.all(
                  color: retro.borderColor,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Center(
                child: RetroIcon(icon, size: 20, color: iconColor),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 5),
                        RetroBadge(
                          text: badge,
                          backgroundColor: badgeColor ?? retro.accentGreen,
                          textColor: Colors.black,
                          fontSize: 6.5,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            RetroIcon(
              'skip_next',
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
