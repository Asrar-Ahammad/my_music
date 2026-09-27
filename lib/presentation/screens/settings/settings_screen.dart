import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../data/services/file_scanner_service.dart';
import '../../providers/equalizer_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/lyrics_settings_provider.dart';
import '../../providers/mini_player_settings_provider.dart';
import '../../providers/now_playing_settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/palette_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/spatial_audio_provider.dart';
import '../../providers/ai_settings_provider.dart';
import '../../providers/library_tagger_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_toast.dart';
import '../../widgets/scan_options_dialog.dart';
import '../onboarding/onboarding_screen.dart';
import '../spatial_audio/spatial_audio_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final miniPlayerSettings = ref.watch(miniPlayerArtSettingsProvider);
    final nowPlayingSettings = ref.watch(nowPlayingArtSettingsProvider);
    final lyricsSettings = ref.watch(lyricsSettingsProvider);
    final lyricsSettingsNotifier = ref.read(lyricsSettingsProvider.notifier);
    final spatialAudioState = ref.watch(spatialAudioProvider);
    final spatialAudioNotifier = ref.read(spatialAudioProvider.notifier);
    final aiSettings = ref.watch(aiSettingsProvider);
    final aiSettingsNotifier = ref.read(aiSettingsProvider.notifier);
    final taggerState = ref.watch(libraryTaggerProvider);
    final taggerNotifier = ref.read(libraryTaggerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    int sectionIdx = 0;
    String nextSection() => (sectionIdx++).toString().padLeft(2, '0');

    final scanFolders = settingsRepo.getScanFolders();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // // APPEARANCE & THEME
          _buildSectionHeader(context, nextSection(), 'APPEARANCE & THEME'),
          RetroCard(
              padding: const EdgeInsets.all(16),
              title: 'VISUAL THEME',
              titleTrailing: RetroBadge(
                text: isDark ? 'DARK' : 'LIGHT',
                backgroundColor: isDark ? retro.cardColor : retro.accentYellow,
                textColor: isDark ? Colors.white : Colors.black,
                fontSize: 8.5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DISPLAY AESTHETIC',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.primary,
                      fontSize: 8.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Switch between warm daytime handheld & neon cyber arcade aesthetics',
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (isDark) themeNotifier.toggleTheme();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: !isDark
                                  ? retro.accentYellow.withValues(alpha: 0.22)
                                  : retro.cardColor,
                              border: Border.all(
                                color: !isDark ? retro.accentYellow : retro.borderColor,
                                width: !isDark ? 2.5 : 1.5,
                              ),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: !isDark
                                        ? retro.accentYellow.withValues(alpha: 0.35)
                                        : retro.cardColor,
                                    border: Border.all(
                                      color: !isDark ? retro.accentYellow : retro.borderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: RetroIcon(
                                      'sun',
                                      size: 18,
                                      color: !isDark ? Colors.black : retro.accentYellow,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'LIGHT RETRO',
                                  style: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 10.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Daytime Handheld',
                                  style: RetroTypography.retroMono(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                    fontSize: 12.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                RetroBadge(
                                  text: !isDark ? 'ACTIVE' : 'SELECT',
                                  backgroundColor: !isDark ? retro.accentYellow : retro.cardColor,
                                  textColor: !isDark ? Colors.black : theme.colorScheme.onSurface,
                                  fontSize: 7.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isDark) themeNotifier.toggleTheme();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                  : retro.cardColor,
                              border: Border.all(
                                color: isDark ? theme.colorScheme.primary : retro.borderColor,
                                width: isDark ? 2.5 : 1.5,
                              ),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? theme.colorScheme.primary.withValues(alpha: 0.25)
                                        : retro.cardColor,
                                    border: Border.all(
                                      color: isDark ? theme.colorScheme.primary : retro.borderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: RetroIcon(
                                      'moon',
                                      size: 18,
                                      color: isDark ? theme.colorScheme.onSurface : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'DARK ARCADE',
                                  style: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 10.0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Cyber Night',
                                  style: RetroTypography.retroMono(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                    fontSize: 12.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                RetroBadge(
                                  text: isDark ? 'ACTIVE' : 'SELECT',
                                  backgroundColor: isDark ? theme.colorScheme.primary : retro.cardColor,
                                  textColor: isDark ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                  fontSize: 7.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _PaletteSelectionCard(),
            const SizedBox(height: 16),
            const _AppFontSelectionCard(),
            const SizedBox(height: 24),

            // // COVER ART STYLING
            _buildSectionHeader(context, nextSection(), 'COVER ART CUSTOMIZATION'),

            // MiniPlayer Cover Art Card
            _buildCoverArtCard(
              context: context,
              title: 'MINIPLAYER COVER ART',
              selectedStyle: miniPlayerSettings.style.name.toUpperCase(),
              isRotating: miniPlayerSettings.isRotating,
              onSelectBox: () {
                ref.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.box);
                RetroToast.show(context, 'MINIPLAYER ART: BOX', icon: 'check');
              },
              onSelectVinyl: () {
                ref.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.vinyl);
                RetroToast.show(context, 'MINIPLAYER ART: VINYL', icon: 'vinyl');
              },
              onSelectCassette: () {
                ref.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.cassette);
                RetroToast.show(context, 'MINIPLAYER ART: CASSETTE', icon: 'cassette');
              },
              onToggleRotation: () {
                final next = !miniPlayerSettings.isRotating;
                ref.read(miniPlayerArtSettingsProvider.notifier).setRotating(next);
                RetroToast.show(
                  context,
                  next ? 'ROTATION: ENABLED' : 'ROTATION: DISABLED',
                  icon: next ? 'check' : 'close',
                );
              },
              vinylIcon: const RetroIcon('vinyl', size: 18),
              cassetteIcon: const RetroIcon('cassette', size: 18),
            ),

            const SizedBox(height: 14),

            // Now Playing Cover Art Card
            _buildCoverArtCard(
              context: context,
              title: 'NOW PLAYING COVER ART',
              selectedStyle: nowPlayingSettings.style.name.toUpperCase(),
              isRotating: nowPlayingSettings.isRotating,
              onSelectBox: () {
                ref.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.box);
                RetroToast.show(context, 'NOW PLAYING ART: BOX', icon: 'check');
              },
              onSelectVinyl: () {
                ref.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.vinyl);
                RetroToast.show(context, 'NOW PLAYING ART: VINYL', icon: 'vinyl');
              },
              onSelectCassette: () {
                ref.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.cassette);
                RetroToast.show(context, 'NOW PLAYING ART: CASSETTE', icon: 'cassette');
              },
              onToggleRotation: () {
                final next = !nowPlayingSettings.isRotating;
                ref.read(nowPlayingArtSettingsProvider.notifier).setRotating(next);
                RetroToast.show(
                  context,
                  next ? 'ROTATION: ENABLED' : 'ROTATION: DISABLED',
                  icon: next ? 'check' : 'close',
                );
              },
              vinylIcon: const RetroIcon('vinyl', size: 18),
              cassetteIcon: const RetroIcon('cassette', size: 18),
            ),

          const SizedBox(height: 16),

          // // LIBRARY MANAGEMENT
          _buildSectionHeader(context, nextSection(), 'MUSIC LIBRARY'),
          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'LIBRARY SCAN DIRECTORIES',
            titleTrailing: RetroButton(
              isCompact: true,
              label: 'IMPORT MUSIC',
              icon: RetroIcon('plus', size: 12, color: theme.colorScheme.onPrimary),
              backgroundColor: theme.colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onPressed: () => ScanOptionsDialog.show(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fetch All Audio Toggle Card
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: retro.cardColor,
                    border: Border.all(color: retro.borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const RetroIcon('disc', size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FETCH ALL AUDIO & MUSIC',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface,
                                fontSize: 10.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scan all standard device folders',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 14.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: settingsRepo.isFetchAllAudio(),
                        activeTrackColor: retro.accentGreen,
                        onChanged: (val) async {
                          if (val) {
                            final confirmed = await _showConfirmFetchAllDialog(context);
                            if (confirmed == true) {
                              await settingsRepo.setFetchAllAudio(true);
                              await libraryNotifier.loadLibrary();
                              if (context.mounted) {
                                RetroToast.show(
                                  context,
                                  'FETCH ALL AUDIO ENABLED',
                                  icon: 'check',
                                  iconColor: retro.accentGreen,
                                );
                              }
                            }
                          } else {
                            await settingsRepo.setFetchAllAudio(false);
                            await libraryNotifier.loadLibrary();
                            if (context.mounted) {
                              RetroToast.show(
                                context,
                                'FETCH ALL AUDIO DISABLED',
                                icon: 'close',
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                if (scanFolders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        const RetroIcon('folder', size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No custom folders added. Only bundled 8-bit sample tracks are loaded.',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 14.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...scanFolders.map((folder) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: retro.cardColor,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          const RetroIcon('folder', size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              folder,
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface,
                                fontSize: 9.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            iconSize: 18,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            icon: const RetroIcon('trash', size: 18),
                            onPressed: () async {
                              await settingsRepo.removeScanFolder(folder);
                              await libraryNotifier.loadLibrary();
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: RetroButton(
                        isCompact: true,
                        label: 'RESCAN FOLDERS',
                        icon: RetroIcon('sort', size: 13, color: theme.colorScheme.onSecondary),
                        backgroundColor: theme.colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () async {
                          await libraryNotifier.loadLibrary();
                          if (context.mounted) {
                            final count = ref.read(libraryProvider).allSongs.length;
                            RetroToast.show(
                              context,
                              'RESCANNED ${scanFolders.length} FOLDERS ($count TRACKS)',
                              icon: 'sort',
                              iconColor: theme.colorScheme.secondary,
                            );
                          }
                        },
                      ),
                    ),
                    if (scanFolders.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      RetroButton(
                        isCompact: true,
                        label: 'CLEAR ALL',
                        icon: const RetroIcon('trash', size: 13, color: Colors.white),
                        backgroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () async {
                          await settingsRepo.clearAllScanFolders();
                          await libraryNotifier.loadLibrary();
                          if (context.mounted) {
                            RetroToast.show(
                              context,
                              'ALL SCAN FOLDERS CLEARED',
                              icon: 'trash',
                              iconColor: theme.colorScheme.error,
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // // SYNCHRONIZED LYRICS (LRC)
          _buildSectionHeader(context, nextSection(), 'SYNCHRONIZED LYRICS (LRC)'),
          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'ONLINE LYRICS SERVICE',
            titleTrailing: RetroBadge(
              text: lyricsSettings.onlineLyricsEnabled ? 'ENABLED' : 'DISABLED',
              backgroundColor: lyricsSettings.onlineLyricsEnabled
                  ? retro.accentGreen
                  : retro.cardColor,
              textColor: lyricsSettings.onlineLyricsEnabled
                  ? Colors.black
                  : theme.colorScheme.onSurface,
              fontSize: 8.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RetroIcon(
                      'sparkles',
                      size: 18,
                      color: lyricsSettings.onlineLyricsEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FETCH ONLINE LYRICS',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 10.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search & stream synced timestamps from LRCLIB & mirrors',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 14.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    RetroButton(
                      isCompact: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      label: lyricsSettings.onlineLyricsEnabled ? 'ONLINE: ON' : 'ONLINE: OFF',
                      backgroundColor: lyricsSettings.onlineLyricsEnabled
                          ? theme.colorScheme.primary
                          : retro.cardColor,
                      textColor: lyricsSettings.onlineLyricsEnabled
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      onPressed: () {
                        final next = !lyricsSettings.onlineLyricsEnabled;
                        lyricsSettingsNotifier.setOnlineLyricsEnabled(next);
                        RetroToast.show(
                          context,
                          next ? 'ONLINE LYRICS: ENABLED' : 'ONLINE LYRICS: DISABLED',
                          icon: next ? 'check' : 'close',
                        );
                      },
                    ),
                  ],
                ),

                if (lyricsSettings.onlineLyricsEnabled) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: lyricsSettings.prioritizeSyllableLyrics
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : retro.cardColor.withValues(alpha: 0.5),
                      border: Border.all(
                        color: retro.borderColor.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        RetroIcon(
                          'music',
                          size: 16,
                          color: lyricsSettings.prioritizeSyllableLyrics
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PRIORITIZE SYLLABLE LYRICS',
                                style: RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 9.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Prioritize word-by-word timestamps when available',
                                style: RetroTypography.retroMono(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        RetroButton(
                          isCompact: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          label: lyricsSettings.prioritizeSyllableLyrics ? 'YES' : 'NO',
                          backgroundColor: lyricsSettings.prioritizeSyllableLyrics
                              ? theme.colorScheme.secondary
                              : retro.cardColor,
                          textColor: lyricsSettings.prioritizeSyllableLyrics
                              ? theme.colorScheme.onSecondary
                              : theme.colorScheme.onSurface,
                          onPressed: () {
                            final next = !lyricsSettings.prioritizeSyllableLyrics;
                            lyricsSettingsNotifier.setPrioritizeSyllableLyrics(next);
                            RetroToast.show(
                              context,
                              next ? 'SYLLABLE LYRICS: PRIORITIZED' : 'STANDARD LINE LYRICS',
                              icon: 'check',
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  Text(
                    'ONLINE LYRIC PROVIDERS',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.primary,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Enabled providers are tried in order (top to bottom). Disable LRCLIB to skip it entirely.',
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'LRCLIB',
                      'LyricsPlus',
                      'PaxSenix',
                      'BetterLyrics',
                      'SimpMusic',
                      'KuGou',
                      'Musixmatch',
                    ].map((source) {
                      final isSelected = lyricsSettings.enabledSources.contains(source);
                      return GestureDetector(
                        onTap: () {
                          lyricsSettingsNotifier.toggleSource(source, !isSelected);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                : retro.cardColor,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : retro.borderColor,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RetroIcon(
                                isSelected ? 'check' : 'plus',
                                size: 11,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                source,
                                style: RetroTypography.pixelBadge(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontSize: 8.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'LOCAL LRC STORAGE FOLDER',
            titleTrailing: RetroBadge(
              text: lyricsSettings.localLrcFolderPath != null ? 'CUSTOM' : 'AUTO',
              backgroundColor: lyricsSettings.localLrcFolderPath != null
                  ? theme.colorScheme.secondary
                  : retro.cardColor,
              textColor: lyricsSettings.localLrcFolderPath != null
                  ? theme.colorScheme.onSecondary
                  : theme.colorScheme.onSurface,
              fontSize: 8.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local .lrc files are matched by song title and always take priority over online requests.',
                  style: RetroTypography.retroMono(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: retro.cardColor,
                    border: Border.all(color: retro.borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const RetroIcon('folder', size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lyricsSettings.localLrcFolderPath ??
                              'Scan alongside audio files & app storage (Default)',
                          style: RetroTypography.pixelBadge(
                            color: lyricsSettings.localLrcFolderPath != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 9.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RetroButton(
                        isCompact: true,
                        label: 'CHOOSE LRC FOLDER',
                        icon: RetroIcon('folder', size: 13, color: theme.colorScheme.onPrimary),
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () async {
                          try {
                            await PermissionHelper.requestStoragePermission();
                          } catch (_) {}

                          try {
                            final picked = await FilePickerPlatform.instance.getDirectoryPath();
                            if (picked != null && picked.isNotEmpty) {
                              final normalized = FileScannerService.normalizeFolderPath(picked);
                              await lyricsSettingsNotifier.setLocalLrcFolderPath(normalized);
                              if (context.mounted) {
                                RetroToast.show(
                                  context,
                                  'LRC DIRECTORY SET: ${normalized.split('/').last}',
                                  icon: 'folder',
                                  iconColor: theme.colorScheme.secondary,
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              RetroToast.show(context, 'PICKER ERROR: $e', icon: 'close');
                            }
                          }
                        },
                      ),
                    ),
                    if (lyricsSettings.localLrcFolderPath != null) ...[
                      const SizedBox(width: 10),
                      RetroButton(
                        isCompact: true,
                        label: 'RESET',
                        icon: const RetroIcon('trash', size: 13, color: Colors.white),
                        backgroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: () async {
                          await lyricsSettingsNotifier.setLocalLrcFolderPath(null);
                          if (context.mounted) {
                            RetroToast.show(
                              context,
                              'RESET TO AUDIO FOLDER SCANNING',
                              icon: 'trash',
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // // ON-DEVICE AUDIO TAGGING
          _buildSectionHeader(context, nextSection(), 'ON-DEVICE AUDIO TAGGING'),
          _buildOnDeviceAiSection(
            context, ref, theme, retro,
            aiSettings, aiSettingsNotifier,
            taggerState, taggerNotifier,
          ),

          const SizedBox(height: 16),

          // // AUDIO ENGINE
          _buildSectionHeader(context, nextSection(), 'AUDIO ENGINE & SYSTEM'),
          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'DOLBY ATMOS & SPATIAL AUDIO',
            titleTrailing: RetroBadge(
              text: spatialAudioState.isEnabled ? 'ACTIVE' : 'OFF',
              backgroundColor: spatialAudioState.isEnabled
                  ? retro.accentGreen
                  : retro.cardColor,
              textColor: spatialAudioState.isEnabled
                  ? Colors.black
                  : theme.colorScheme.onSurface,
              fontSize: 8.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: spatialAudioState.isEnabled
                            ? (retro.isDark
                                ? retro.cardColor
                                : theme.colorScheme.primary)
                            : retro.cardColor,
                        border: Border.all(
                          color: spatialAudioState.isEnabled
                              ? (retro.isDark
                                  ? retro.accentGreen
                                  : theme.colorScheme.primary)
                              : retro.borderColor,
                          width: 2.0,
                        ),
                      ),
                      child: Center(
                        child: RetroIcon(
                          'dolby_atmos',
                          size: 22,
                          color: spatialAudioState.isEnabled
                              ? (retro.isDark
                                  ? retro.accentGreen
                                  : theme.colorScheme.onPrimary)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DOLBY ATMOS & 3D VIRTUALIZER',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            spatialAudioState.isEnabled
                                ? '${spatialAudioState.currentPreset} • ${(spatialAudioState.strength / 10).round()}%'
                                : 'Hardware 3D virtualization disabled',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: spatialAudioState.isEnabled,
                      activeTrackColor: retro.accentGreen,
                      onChanged: (val) async {
                        await spatialAudioNotifier.toggleEnabled(val);
                        if (context.mounted) {
                          RetroToast.show(
                            context,
                            val ? 'SPATIAL AUDIO ENABLED' : 'SPATIAL AUDIO DISABLED',
                            icon: val ? 'check' : 'close',
                            iconColor: val ? retro.accentGreen : retro.accentYellow,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RetroButton(
                        isCompact: true,
                        label: 'OPEN SPATIAL STUDIO',
                        backgroundColor: theme.colorScheme.primary,
                        textColor: theme.colorScheme.onPrimary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SpatialAudioScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RetroButton(
                        isCompact: true,
                        label: 'SYSTEM DOLBY DSP',
                        backgroundColor: retro.cardColor,
                        textColor: theme.colorScheme.onSurface,
                        onPressed: () async {
                          final ok = await spatialAudioNotifier.openSystemSettings();
                          if (!ok && context.mounted) {
                            RetroToast.show(
                              context,
                              'SYSTEM AUDIO PANEL NOT FOUND',
                              icon: 'alert',
                              iconColor: retro.accentYellow,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'AUDIO ENGINE SPECS',
            titleTrailing: RetroBadge(
              text: 'HI-RES + ATMOS',
              backgroundColor: retro.accentGreen,
              textColor: Colors.black,
              fontSize: 8.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSpecRow(
                  context,
                  'DECODER BACKEND',
                  'just_audio + Native FLAC/ALAC decoder',
                ),
                _buildSpecRow(
                  context,
                  'MAX RESOLUTION',
                  '24-Bit / 192 kHz lossless playback',
                ),
                _buildSpecRow(
                  context,
                  'DOLBY ATMOS & 3D',
                  spatialAudioState.isEnabled
                      ? 'Active (${spatialAudioState.currentPreset})'
                      : 'Supported (Disabled)',
                ),
                _buildSpecRow(
                  context,
                  'VIRTUALIZER ENGINE',
                  'Android Spatializer & Hardware 3D DSP',
                ),
                _buildSpecRow(
                  context,
                  'SUPPORTED CODECS',
                  'FLAC, ALAC, WAV (PCM), MP3, AAC, AC3, EAC3',
                ),
                _buildSpecRow(
                  context,
                  'GAPLESS PLAYBACK',
                  'Active (ConcatenatingAudioSource)',
                ),
                _buildSpecRow(
                  context,
                  'BACKGROUND SERVICE',
                  'audio_service enabled',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // // ABOUT & INFO
          _buildSectionHeader(context, nextSection(), 'ABOUT & SYSTEM INFO'),
          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'ABOUT ${AppConstants.appName.toUpperCase()}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      AppConstants.appName,
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.primary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    RetroBadge(
                      text: 'v${AppConstants.appVersion}',
                      backgroundColor: retro.cardColor,
                      fontSize: 8.5,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.appTagline,
                  style: RetroTypography.retroMono(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: retro.cardColor.withValues(alpha: 0.5),
                    border: Border.all(color: retro.borderColor.withValues(alpha: 0.4), width: 1.0),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    'Pixelarticons (MIT) • Press Start 2P & VT323 (SIL OFL)\nPure 8-bit synthetic chiptune waveforms',
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                RetroButton(
                  isCompact: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  icon: const RetroIcon('info', size: 15),
                  label: 'VIEW FEATURE TOUR',
                  backgroundColor: retro.cardColor,
                  textColor: theme.colorScheme.onSurface,
                  borderColor: retro.borderColor,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(isReplay: true),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Made with ',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 10.5,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: RetroIcon(
                    'heart_filled',
                    size: 15,
                    color: Color(0xFFE53935),
                  ),
                ),
                Text(
                  ' by Asrar',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String number, String title) {
    final theme = Theme.of(context);
    final retro = context.retro;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 2, right: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              border: Border.all(
                color: theme.colorScheme.primary.computeLuminance() > 0.4
                    ? retro.borderColor
                    : theme.colorScheme.primary,
                width: 1.5,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(
              number,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onPrimary,
                fontSize: 8.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1.5,
              color: retro.borderColor.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverArtCard({
    required BuildContext context,
    required String title,
    required String selectedStyle,
    required bool isRotating,
    required VoidCallback onSelectBox,
    required VoidCallback onSelectVinyl,
    required VoidCallback onSelectCassette,
    required VoidCallback onToggleRotation,
    required Widget vinylIcon,
    required Widget cassetteIcon,
  }) {
    final theme = Theme.of(context);
    final retro = context.retro;

    final isBox = selectedStyle == 'BOX';
    final isVinyl = selectedStyle == 'VINYL';
    final isCassette = selectedStyle == 'CASSETTE';
    final hasRotation = isVinyl || isCassette;

    return RetroCard(
      padding: const EdgeInsets.all(16),
      title: title,
      titleTrailing: RetroBadge(
        text: selectedStyle,
        backgroundColor: !isBox ? theme.colorScheme.primary : retro.cardColor,
        textColor: !isBox ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontSize: 8.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 1. BOX Option
              Expanded(
                child: GestureDetector(
                  onTap: onSelectBox,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isBox
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : retro.cardColor,
                      border: Border.all(
                        color: isBox ? theme.colorScheme.primary : retro.borderColor,
                        width: isBox ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: retro.cardColor,
                            border: Border.all(color: retro.borderColor, width: 1.2),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: const Center(
                            child: RetroIcon('music', size: 10),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'BOX',
                          style: RetroTypography.pixelBadge(
                            color: isBox ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontSize: 9.0,
                          ),
                        ),
                        if (isBox) ...[
                          const SizedBox(width: 3),
                          RetroIcon('check', size: 11, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. VINYL Option
              Expanded(
                child: GestureDetector(
                  onTap: onSelectVinyl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isVinyl
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : retro.cardColor,
                      border: Border.all(
                        color: isVinyl ? theme.colorScheme.primary : retro.borderColor,
                        width: isVinyl ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        vinylIcon,
                        const SizedBox(width: 4),
                        Text(
                          'VINYL',
                          style: RetroTypography.pixelBadge(
                            color: isVinyl ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontSize: 9.0,
                          ),
                        ),
                        if (isVinyl) ...[
                          const SizedBox(width: 3),
                          RetroIcon('check', size: 11, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. CASSETTE Option
              Expanded(
                child: GestureDetector(
                  onTap: onSelectCassette,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCassette
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : retro.cardColor,
                      border: Border.all(
                        color: isCassette ? theme.colorScheme.primary : retro.borderColor,
                        width: isCassette ? 2.0 : 1.5,
                      ),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        cassetteIcon,
                        const SizedBox(width: 4),
                        Text(
                          'CASSETTE',
                          style: RetroTypography.pixelBadge(
                            color: isCassette ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontSize: 9.0,
                          ),
                        ),
                        if (isCassette) ...[
                          const SizedBox(width: 3),
                          RetroIcon('check', size: 11, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (hasRotation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isRotating
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : retro.cardColor.withValues(alpha: 0.5),
                border: Border.all(
                  color: retro.borderColor.withValues(alpha: 0.5),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  RetroIcon(
                    'refresh',
                    size: 16,
                    color: isRotating ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isCassette ? 'ANIMATE SPOOLS ON PLAYBACK' : 'ROTATE VINYL ON PLAYBACK',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 9.0,
                      ),
                    ),
                  ),
                  RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    label: isRotating ? 'ENABLED' : 'DISABLED',
                    backgroundColor: isRotating
                        ? theme.colorScheme.primary
                        : retro.cardColor,
                    textColor: isRotating
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    onPressed: onToggleRotation,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.primary,
                fontSize: 9.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: RetroTypography.retroMono(
                color: theme.colorScheme.onSurface,
                fontSize: 14.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmFetchAllDialog(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: retro.cardColor,
        shape: Border.all(
          color: theme.colorScheme.primary,
          width: 2.5,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                border: Border.all(color: theme.colorScheme.primary, width: 1.5),
              ),
              child: RetroIcon('info', size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'CONFIRM FULL SCAN',
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: Text(
                'FETCH ALL AUDIO will scan all standard device folders (Music, Downloads, Audio, Podcasts).\n\nNotice: This may include non-music audio like voice recordings or notification sounds.\n\nDo you want to enable Fetch All Audio?',
                style: RetroTypography.retroMono(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
                  fontSize: 16.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        actions: [
          RetroButton(
            isCompact: true,
            label: 'CANCEL',
            backgroundColor: retro.cardColor,
            textColor: theme.colorScheme.onSurface,
            borderColor: retro.borderColor,
            onPressed: () => Navigator.of(dialogCtx).pop(false),
          ),
          RetroButton(
            isCompact: true,
            label: 'YES, FETCH ALL',
            icon: const RetroIcon('check', size: 14, color: Colors.black),
            backgroundColor: retro.accentGreen,
            textColor: Colors.black,
            borderColor: retro.borderColor,
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildOnDeviceAiSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    RetroThemeTokens retro,
    AiSettingsState aiSettings,
    AiSettingsNotifier aiNotifier,
    LibraryTaggerState taggerState,
    LibraryTaggerNotifier taggerNotifier,
  ) {
    final libraryState = ref.read(libraryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master Toggle Card
        RetroCard(
          padding: const EdgeInsets.all(16),
          title: 'ON-DEVICE AUDIO TAGGER',
          titleTrailing: RetroBadge(
            text: aiSettings.isAiEnabled ? 'ENABLED' : 'DISABLED',
            backgroundColor: aiSettings.isAiEnabled ? retro.accentGreen : retro.cardColor,
            textColor: aiSettings.isAiEnabled ? Colors.black : theme.colorScheme.onSurface,
            fontSize: 8.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RetroIcon(
                    'sparkles',
                    size: 20,
                    color: aiSettings.isAiEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ENABLE SMART AUDIO TAGGING',
                          style: RetroTypography.pixelBadge(color: theme.colorScheme.onSurface, fontSize: 10.0),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Analyzes local audio files with lightweight on-device DSP to detect mood, genre, and energy levels without external network dependencies.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: aiSettings.isAiEnabled,
                    activeThumbColor: theme.colorScheme.primary,
                    activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.3),
                    inactiveThumbColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    onChanged: (_) => aiNotifier.toggleAiEnabled(),
                  ),
                ],
              ),
            ],
          ),
        ),

        if (aiSettings.isAiEnabled) ...[
          const SizedBox(height: 12),

          RetroCard(
            padding: const EdgeInsets.all(16),
            title: 'OFFLINE MOOD & GENRE TAGGER',
            titleTrailing: RetroBadge(
              text: taggerState.isScanning
                  ? 'SCANNING'
                  : taggerState.taggedSongs.isNotEmpty
                      ? '${taggerState.taggedSongs.length} TAGGED'
                      : 'READY',
              backgroundColor: taggerState.isScanning
                  ? theme.colorScheme.primary
                  : taggerState.taggedSongs.isNotEmpty
                      ? retro.accentGreen
                      : retro.cardColor,
              textColor: taggerState.isScanning
                  ? theme.colorScheme.onPrimary
                  : taggerState.taggedSongs.isNotEmpty
                      ? Colors.black
                      : theme.colorScheme.onSurface,
              fontSize: 8.5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyses a 5-second audio window from each untagged track and assigns Mood, Genre, and Energy level tags. Runs offline in the background using pure on-device signal processing.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.35,
                  ),
                ),
                if (taggerState.isScanning) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: LinearProgressIndicator(
                      value: taggerState.progress > 0 ? taggerState.progress : null,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ANALYSING ${taggerState.scannedCount} / ${taggerState.totalCount}'
                          '${taggerState.currentSongTitle != null ? " · ${taggerState.currentSongTitle!.toUpperCase()}" : ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: taggerNotifier.cancelScan,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: Text('CANCEL',
                              style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: RetroButton(
                            label: 'SCAN LIBRARY',
                            icon: const RetroIcon('sparkles', size: 15),
                            onPressed: () => taggerNotifier.startScan(libraryState.allSongs),
                          ),
                        ),
                      ),
                      if (taggerState.taggedSongs.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        RetroButton(
                          isCompact: true,
                          label: 'CLEAR',
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          borderColor: Colors.red.withValues(alpha: 0.5),
                          textColor: Colors.red,
                          icon: const RetroIcon('trash', size: 14, color: Colors.red),
                          onPressed: () => _confirmClearAllTags(context, taggerNotifier),
                        ),
                      ],
                    ],
                  ),
                ],
                if (taggerState.taggedSongs.isNotEmpty && !taggerState.isScanning) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...taggerState.availableMoods.take(4).map((m) => _buildTagChip(m, theme.colorScheme.primary, theme)),
                      ...taggerState.availableGenres.take(4).map((g) => _buildTagChip(g, retro.accentGreen, theme)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (aiSettings.totalStorageBytes > 0) ...[
            const SizedBox(height: 12),

            // Storage Reclaim Card (if user previously had downloaded weights)
            RetroCard(
              padding: const EdgeInsets.all(16),
              title: 'RECLAIM STORAGE',
              titleTrailing: RetroBadge(
                text: aiSettings.formattedTotalStorage,
                backgroundColor: Colors.red.withValues(alpha: 0.15),
                textColor: Colors.red,
                fontSize: 8.5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Disk space occupied by leftover model files from legacy features. Tap to delete and reclaim space.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      RetroButton(
                        isCompact: true,
                        backgroundColor: Colors.red.withValues(alpha: 0.15),
                        borderColor: Colors.red.withValues(alpha: 0.6),
                        textColor: Colors.red,
                        label: 'DELETE ALL',
                        icon: const RetroIcon('trash', size: 14, color: Colors.red),
                        onPressed: () => _confirmDeleteAllModels(context, aiNotifier),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTagChip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _confirmClearAllTags(BuildContext context, LibraryTaggerNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CLEAR ALL AI TAGS?'),
        content: const Text('This will remove all mood, genre and energy tags generated for your library. The library can be re-scanned at any time.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CLEAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.clearAllTags();
  }


  Future<void> _confirmDeleteAllModels(
    BuildContext context,
    AiSettingsNotifier aiNotifier,
  ) async {
    final theme = Theme.of(context);
    final retro = context.retro;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: retro.cardColor,
        shape: Border.all(color: Colors.red.withValues(alpha: 0.8), width: 2.0),
        title: Text(
          'DELETE ALL AI MODELS?',
          style: RetroTypography.pixelHeader(color: theme.colorScheme.onSurface, fontSize: 12),
        ),
        content: const Text(
          'This will permanently delete all downloaded Hugging Face model weights from device storage and free up space.',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE ALL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await aiNotifier.deleteAllModels();
      if (context.mounted) {
        RetroToast.show(context, 'All AI models deleted');
      }
    }
  }
}

class _PaletteSelectionCard extends ConsumerWidget {
  const _PaletteSelectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final paletteState = ref.watch(paletteProvider);
    final paletteNotifier = ref.read(paletteProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    final palettes = isDark ? RetroColors.darkPalettes : RetroColors.lightPalettes;
    final activeId = isDark ? paletteState.darkPaletteId : paletteState.lightPaletteId;
    final safeActiveId = palettes.any((p) => p.id == activeId) ? activeId : palettes.first.id;
    final activePalette = palettes.firstWhere((p) => p.id == safeActiveId);

    return RetroCard(
      padding: const EdgeInsets.all(16),
      title: 'COLOR PALETTE',
      titleTrailing: RetroBadge(
        text: isDark ? 'DARK PALETTES' : 'LIGHT PALETTES',
        backgroundColor: retro.cardColor,
        textColor: theme.colorScheme.primary,
        fontSize: 8.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLOR PALETTES',
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.primary,
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select handcrafted ${isDark ? "dark" : "light"} 8-bit color ways with tailored accent hues',
            style: RetroTypography.retroMono(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),

          // Active palette preview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border.all(
                color: retro.borderColor,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activePalette.name,
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.primary,
                        fontSize: 12.0,
                      ),
                    ),
                    RetroBadge(
                      text: isDark ? 'DARK MODE' : 'LIGHT MODE',
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      textColor: theme.colorScheme.primary,
                      fontSize: 7.5,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: activePalette.swatchColors.map((color) {
                    return Expanded(
                      child: Container(
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: color,
                          border: Border.all(
                            color: retro.borderColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dropdown selector
          Text(
            'SELECT ${isDark ? "DARK" : "LIGHT"} PALETTE',
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.onSurface,
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border.all(
                color: retro.borderColor,
                width: retro.borderWidth,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('palette_dropdown'),
                value: safeActiveId,
                isExpanded: true,
                dropdownColor: retro.cardColor,
                borderRadius: BorderRadius.zero,
                icon: RetroIcon(
                  'chevron_down',
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                selectedItemBuilder: (context) {
                  return palettes.map((p) {
                    return Row(
                      children: [
                        _buildSwatchBox(p, retro),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p.name,
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 10.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        RetroBadge(
                          text: 'ACTIVE',
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          fontSize: 7.5,
                        ),
                      ],
                    );
                  }).toList();
                },
                items: palettes.map((p) {
                  final isSelected = p.id == safeActiveId;
                  return DropdownMenuItem<String>(
                    value: p.id,
                    child: Row(
                      children: [
                        _buildSwatchBox(p, retro),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: RetroTypography.pixelBadge(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontSize: 9.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSelected
                                    ? 'Currently Applied'
                                    : (isDark ? 'Dark Mode Palette' : 'Light Mode Palette'),
                                style: RetroTypography.retroMono(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          RetroBadge(
                            text: 'ACTIVE',
                            backgroundColor: theme.colorScheme.primary,
                            textColor: theme.colorScheme.onPrimary,
                            fontSize: 7.5,
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newId) {
                  if (newId == null) return;
                  final selected = palettes.firstWhere((p) => p.id == newId);
                  if (isDark) {
                    paletteNotifier.setDarkPalette(selected.id);
                  } else {
                    paletteNotifier.setLightPalette(selected.id);
                  }
                  RetroToast.show(
                    context,
                    'APPLIED PALETTE: ${selected.name}',
                    icon: 'sparkles',
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwatchBox(RetroPaletteData p, RetroThemeTokens retro) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        border: Border.all(
          color: retro.borderColor.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: p.swatchColors
            .map((color) => Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AppFontSelectionCard extends ConsumerStatefulWidget {
  const _AppFontSelectionCard();

  @override
  ConsumerState<_AppFontSelectionCard> createState() => _AppFontSelectionCardState();
}

class _AppFontSelectionCardState extends ConsumerState<_AppFontSelectionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final activeFontFamily = ref.watch(fontProvider);
    final fontNotifier = ref.read(fontProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    final fonts = RetroTypography.availableFonts;
    final activeOption = RetroTypography.currentFontOption;

    return RetroCard(
      padding: const EdgeInsets.all(16),
      title: 'APP FONT',
      titleTrailing: RetroBadge(
        text: activeOption.displayName.toUpperCase(),
        backgroundColor: retro.accentYellow,
        textColor: Colors.black,
        fontSize: 8.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TYPOGRAPHY STYLE',
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.primary,
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select your retro typeface for headers, titles, badges, and interface text',
            style: RetroTypography.retroMono(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),

          // Live Font Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PREVIEW // ${activeOption.displayName.toUpperCase()}',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.primary,
                        fontSize: 8.0,
                      ),
                    ),
                    RetroBadge(
                      text: activeOption.category,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                      textColor: theme.colorScheme.primary,
                      fontSize: 7.0,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '8-BIT STEREO HI-RES AUDIO',
                  style: TextStyle(
                    fontFamily: activeOption.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The quick brown fox jumps over 1337 lazy dogs • 0123456789',
                  style: TextStyle(
                    fontFamily: activeOption.fontFamily,
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Toggle Expand / Collapse Button
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: _isExpanded
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : retro.cardColor,
                border: Border.all(
                  color: _isExpanded ? theme.colorScheme.primary : retro.borderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RetroIcon(
                    _isExpanded ? 'arrow_up' : 'chevron_down',
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isExpanded ? 'COLLAPSE FONT LIST' : 'SELECT APP FONT (${fonts.length} AVAILABLE)',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 9.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 14),
            // List of fonts
            ...fonts.map((font) {
              final isSelected = font.fontFamily == activeFontFamily;
              return GestureDetector(
                onTap: () {
                  fontNotifier.setFont(font.fontFamily);
                  RetroToast.show(
                    context,
                    'APP FONT: ${font.displayName.toUpperCase()}',
                    icon: 'check',
                    iconColor: retro.accentGreen,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : retro.cardColor,
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : retro.borderColor,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    font.displayName,
                                    style: TextStyle(
                                      fontFamily: font.fontFamily,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                RetroBadge(
                                  text: font.category,
                                  backgroundColor: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.25)
                                      : theme.colorScheme.surface,
                                  textColor: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 7.0,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              font.description,
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12.0,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'ABCDEFGHIJK 0123456789 ♪ ♫',
                              style: TextStyle(
                                fontFamily: font.fontFamily,
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RetroBadge(
                        text: isSelected ? 'ACTIVE' : 'SELECT',
                        backgroundColor: isSelected ? theme.colorScheme.primary : retro.cardColor,
                        textColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        fontSize: 8.0,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

