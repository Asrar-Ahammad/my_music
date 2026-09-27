import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/permission_helper.dart';
import '../../../data/services/file_scanner_service.dart';
import '../../providers/equalizer_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/lyrics_settings_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_scanline_overlay.dart';
import '../../widgets/retro_toast.dart';

/// Onboarding screen introducing first-time users to the standout features
/// of the 8-bit retro music player. Displayed once on initial launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool isReplay;

  const OnboardingScreen({
    super.key,
    this.isReplay = false,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime? _lastBackPressTime;

  static const int _totalPages = 6;

  bool _fetchAllAudio = false;
  List<String> _scanFolders = [];

  @override
  void initState() {
    super.initState();
    final settingsRepo = ref.read(settingsRepositoryProvider);
    _fetchAllAudio = settingsRepo.isFetchAllAudio();
    _scanFolders = settingsRepo.getScanFolders();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    await ref.read(libraryProvider.notifier).loadLibrary();
    if (widget.isReplay && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      HapticFeedback.selectionClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedback.selectionClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _handleBackPress(bool didPop) {
    if (didPop) return;

    if (_currentPage > 0) {
      _previousPage();
      return;
    }

    if (widget.isReplay) {
      Navigator.of(context).pop();
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      RetroToast.show(
        context,
        'PRESS BACK AGAIN TO EXIT',
        icon: 'arrow_left',
      );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleBackPress(didPop),
      child: RetroScanlineOverlay(
        enabled: true,
        opacity: 0.03,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header Bar
                _buildHeader(theme, retro),

                // Main Slide Content (PageView)
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _buildStage1(theme, retro),
                      _buildStage2(theme, retro),
                      _buildStage3(theme, retro),
                      _buildStage4(theme, retro),
                      _buildStage5(theme, retro),
                      _buildStage6(theme, retro),
                    ],
                  ),
                ),

                // Bottom Navigation & Indicators Bar
                _buildBottomBar(theme, retro),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, RetroThemeTokens retro) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border(
          bottom: BorderSide(
            color: retro.borderColor,
            width: retro.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          // App Logo & Brand
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              border: Border.all(color: retro.borderColor, width: 2.0),
              borderRadius: BorderRadius.zero,
            ),
            child: RetroIcon('music', size: 16, color: theme.colorScheme.onPrimary),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppConstants.appName.toUpperCase(),
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppConstants.appTagline,
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 6.5,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Stage Badge
          RetroBadge(
            text: 'STAGE ${_currentPage + 1}/$_totalPages',
            backgroundColor: theme.colorScheme.surface,
            textColor: theme.colorScheme.primary,
            fontSize: 8.5,
          ),
          const SizedBox(width: 8),

          // Skip Button
          RetroButton(
            isCompact: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            label: 'SKIP',
            backgroundColor: retro.cardColor,
            textColor: theme.colorScheme.onSurface,
            borderColor: retro.borderColor,
            onPressed: _finishOnboarding,
          ),
        ],
      ),
    );
  }

  // --- STAGE 1: 8-BIT RETRO AUDIO ---
  Widget _buildStage1(ThemeData theme, RetroThemeTokens retro) {
    return _buildStageLayout(
      theme: theme,
      retro: retro,
      heroIcon: 'music',
      heroIconColor: theme.colorScheme.primary,
      heroBadgeText: 'HI-RES SOUND ENGINE',
      heroBadgeColor: theme.colorScheme.primary,
      title: '8-BIT RETRO AUDIO',
      tagline: 'NOSTALGIC SOUND • STUDIO FIDELITY',
      features: const [
        _FeatureItem(
          icon: 'play',
          title: 'AUTHENTIC ARCADE EXPERIENCE',
          description:
              'Crisp pixel typography, authentic CRT scanlines, chunky tactile 2.5px borders, and zero modern flat blur.',
        ),
        _FeatureItem(
          icon: 'disc',
          title: 'HI-RES AUDIO FORMATS',
          description:
              'Full offline support for FLAC, WAV (up to 24-bit/96kHz), MP3, AAC, and OGG with lossless playback.',
        ),
        _FeatureItem(
          icon: 'music',
          title: 'BUNDLED CHIPTUNES',
          description:
              'Pre-loaded with 3 nostalgic 8-bit adventure quest tracks ready to play right out of the box.',
        ),
      ],
    );
  }

  // --- STAGE 2: LOCAL LIBRARY & SMART SCAN ---
  Widget _buildStage2(ThemeData theme, RetroThemeTokens retro) {
    return _buildStageLayout(
      theme: theme,
      retro: retro,
      heroIcon: 'folder',
      heroIconColor: retro.accentYellow,
      heroBadgeText: '100% PRIVATE & OFFLINE',
      heroBadgeColor: retro.accentYellow,
      heroBadgeTextColor: Colors.black,
      title: 'DEEP LOCAL SCANNING',
      tagline: 'YOUR MUSIC • ZERO TRACKING',
      features: const [
        _FeatureItem(
          icon: 'folder',
          title: 'CUSTOM FOLDER SELECTION',
          description:
              'Pick specific local directories or external SD cards. Pull down anytime to rescan changes in seconds.',
        ),
        _FeatureItem(
          icon: 'search',
          title: 'INSTANT SEARCH & SORTING',
          description:
              'Find songs, albums, and artists instantly with filter tags and sort modes by title, artist, duration, or format.',
        ),
        _FeatureItem(
          icon: 'playlist',
          title: 'BATCH TRACK SELECTION',
          description:
              'Select multiple tracks with one tap to build playlists, reorder favorites, or queue up whole albums.',
        ),
      ],
    );
  }

  // --- STAGE 3: CASSETTE, VINYL & LYRICS ---
  Widget _buildStage3(ThemeData theme, RetroThemeTokens retro) {
    return _buildStageLayout(
      theme: theme,
      retro: retro,
      heroIcon: 'vinyl',
      heroIconColor: retro.accentGreen,
      heroBadgeText: 'ANALOG AUDIO VIBES',
      heroBadgeColor: retro.accentGreen,
      heroBadgeTextColor: Colors.black,
      title: 'VINYL & SYNCED LYRICS',
      tagline: 'ROTATING DISCS • KARAOKE PRECISION',
      features: const [
        _FeatureItem(
          icon: 'vinyl',
          title: 'VINYL & CASSETTE ART STYLES',
          description:
              'Toggle between spinning vinyl record discs and vintage cassette cases with procedural pixel placeholders.',
        ),
        _FeatureItem(
          icon: 'sliders',
          title: 'SYNCHRONIZED LRC LYRICS',
          description:
              'Word and syllable synchronized karaoke lyrics with automatic local .lrc file discovery and offset controls.',
        ),
        _FeatureItem(
          icon: 'equalizer',
          title: '5-BAND GRAPHIC EQUALIZER',
          description:
              'Custom audio shaping with 5-band graphic EQ presets, bass boost, and configurable sleep timer.',
        ),
      ],
    );
  }

  // --- STAGE 4: SMART QUEUE & PALETTES ---
  Widget _buildStage4(ThemeData theme, RetroThemeTokens retro) {
    return _buildStageLayout(
      theme: theme,
      retro: retro,
      heroIcon: 'shuffle',
      heroIconColor: theme.colorScheme.primary,
      heroBadgeText: 'ULTIMATE CONTROL',
      heroBadgeColor: theme.colorScheme.primary,
      title: 'SMART QUEUE & THEMES',
      tagline: 'SEAMLESS SHUFFLE • 8 RETRO PALETTES',
      features: const [
        _FeatureItem(
          icon: 'shuffle',
          title: 'SMART UNINTERRUPTED SHUFFLE',
          description:
              'Shuffle randomizes with no playback pause. Unshuffle instantly restores the original order without skipping.',
        ),
        _FeatureItem(
          icon: 'settings',
          title: '8 CURATED COLOR PALETTES',
          description:
              'Dark: Warm Espresso, Cyber Slate, Obsidian Olive, Jet Black (OLED). Light: Vintage Handheld, Desert Sage, Olive Grove, Pastel Lavender.',
        ),
        _FeatureItem(
          icon: 'check',
          title: 'LOCKSCREEN & NOTIFICATIONS',
          description:
              'Full system audio controls, artwork notification tiles, and custom repeat mode actions.',
        ),
      ],
    );
  }

  // --- STAGE 5: AUDIO SOURCE SETUP (ALL AUDIO VS SPECIFIC FOLDER) ---
  Widget _buildStage5(ThemeData theme, RetroThemeTokens retro) {
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStageHero(
            retro: retro,
            heroIcon: 'disc',
            heroIconColor: theme.colorScheme.primary,
            heroBadgeText: 'AUDIO SOURCE SETUP',
            heroBadgeColor: theme.colorScheme.primary,
            title: 'SELECT MUSIC SOURCE',
            tagline: 'CHOOSE HOW TO IMPORT YOUR TUNES',
            theme: theme,
          ),
          const SizedBox(height: 16),

          // Option 1: Fetch All Audio & Music Toggle
          RetroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: retro.cardColor,
            borderColor: retro.borderColor,
            borderWidth: 2.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: RetroIcon(
                        'disc',
                        size: 18,
                        color: theme.colorScheme.primary,
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
                                  'FETCH ALL AUDIO & MUSIC',
                                  style: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              RetroBadge(
                                text: _fetchAllAudio ? 'ON' : 'OFF',
                                backgroundColor: _fetchAllAudio
                                    ? retro.accentGreen
                                    : theme.colorScheme.surface,
                                textColor: _fetchAllAudio ? Colors.black : theme.colorScheme.onSurface,
                                fontSize: 7,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Scan all standard device folders (Music, Downloads, Audio, Podcasts)',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _fetchAllAudio,
                      activeTrackColor: retro.accentGreen,
                      onChanged: (val) => _handleToggleFetchAll(val),
                    ),
                  ],
                ),
                if (_fetchAllAudio) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: retro.accentGreen.withValues(alpha: 0.15),
                      border: Border.all(color: retro.accentGreen, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        RetroIcon('check', size: 14, color: retro.accentGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'FULL DEVICE SCAN ENABLED: Scans all audio directories on launch',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 7.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Option 2: Select Specific Folder
          RetroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: retro.cardColor,
            borderColor: retro.borderColor,
            borderWidth: 2.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: RetroIcon(
                        'folder',
                        size: 18,
                        color: retro.accentYellow,
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
                                  'SELECT SPECIFIC FOLDER',
                                  style: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              RetroBadge(
                                text: 'RECOMMENDED',
                                backgroundColor: retro.accentYellow,
                                textColor: Colors.black,
                                fontSize: 6.5,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Pick custom folders (e.g. Music, SD card). Keeps alerts and non-music audio out.',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Folder action buttons
                Row(
                  children: [
                    Expanded(
                      child: RetroButton(
                        isCompact: true,
                        label: 'BROWSE FOLDERS',
                        icon: RetroIcon('folder', size: 13, color: theme.colorScheme.onPrimary),
                        backgroundColor: theme.colorScheme.primary,
                        onPressed: () async {
                          try {
                            await PermissionHelper.requestStoragePermission();
                          } catch (_) {}

                          try {
                            final picked = await FilePickerPlatform.instance.getDirectoryPath();
                            if (picked != null && picked.isNotEmpty) {
                              final normalized = FileScannerService.normalizeFolderPath(picked);
                              await settingsRepo.addScanFolder(normalized);
                              setState(() {
                                _scanFolders = settingsRepo.getScanFolders();
                              });
                              if (mounted) {
                                RetroToast.show(
                                  context,
                                  'ADDED: ${normalized.split('/').last}',
                                  icon: 'folder',
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              RetroToast.show(context, 'PICKER ERROR: $e', icon: 'close');
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    RetroButton(
                      isCompact: true,
                      label: 'PICK FILES',
                      icon: RetroIcon('plus', size: 13, color: theme.colorScheme.onSurface),
                      backgroundColor: retro.cardColor,
                      textColor: theme.colorScheme.onSurface,
                      borderColor: retro.borderColor,
                      onPressed: () async {
                        try {
                          final files = await FilePickerPlatform.instance.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'],
                          );
                          if (files.isNotEmpty) {
                            final valid = files.map((f) => f.path).whereType<String>().toList();
                            if (valid.isNotEmpty) {
                              await libraryNotifier.addCustomAudioFiles(valid);
                              if (mounted) {
                                RetroToast.show(
                                  context,
                                  'IMPORTED ${valid.length} AUDIO FILES',
                                  icon: 'music',
                                );
                              }
                            }
                          }
                        } catch (_) {}
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Selected Folders List
                if (_scanFolders.isNotEmpty) ...[
                  Text(
                    'SELECTED FOLDERS (${_scanFolders.length}):',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.primary,
                      fontSize: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._scanFolders.map((folder) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const RetroIcon('folder', size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              folder,
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface,
                                fontSize: 8.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            iconSize: 14,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const RetroIcon('trash', size: 14),
                            onPressed: () async {
                              await settingsRepo.removeScanFolder(folder);
                              setState(() {
                                _scanFolders = settingsRepo.getScanFolders();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: retro.borderColor, width: 1.2),
                    ),
                    child: Text(
                      'No specific folder chosen yet. Bundled 8-bit chiptunes will play by default if left unconfigured.',
                      style: RetroTypography.retroMono(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STAGE 6: LYRICS DIRECTORY SETUP ---
  Widget _buildStage6(ThemeData theme, RetroThemeTokens retro) {
    final lyricsSettings = ref.watch(lyricsSettingsProvider);
    final lyricsNotifier = ref.read(lyricsSettingsProvider.notifier);

    final customLrcFolder = lyricsSettings.localLrcFolderPath;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildStageHero(
            retro: retro,
            heroIcon: 'sliders',
            heroIconColor: retro.accentGreen,
            heroBadgeText: 'LYRICS DIRECTORY SETUP',
            heroBadgeColor: retro.accentGreen,
            heroBadgeTextColor: Colors.black,
            title: 'SELECT LYRICS FOLDER',
            tagline: 'SYNCHRONIZED .LRC KARAOKE',
            theme: theme,
          ),
          const SizedBox(height: 16),

          // Overview Card
          RetroCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: retro.cardColor,
            borderColor: retro.borderColor,
            borderWidth: 2.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const RetroIcon('sliders', size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KARAOKE .LRC SYNC ENGINE',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Select a dedicated folder containing your LRC files, or scan alongside audio files.',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Current lyrics folder container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border.all(color: retro.borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const RetroIcon('folder', size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customLrcFolder != null
                                  ? 'CUSTOM LYRICS DIRECTORY'
                                  : 'DEFAULT LYRICS DIRECTORY',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.primary,
                                fontSize: 8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              customLrcFolder ??
                                  'Scan alongside audio files & app storage (Default)',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                fontSize: 12.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      RetroBadge(
                        text: customLrcFolder != null ? 'CUSTOM' : 'DEFAULT',
                        backgroundColor: customLrcFolder != null
                            ? retro.accentGreen
                            : theme.colorScheme.surface,
                        textColor: customLrcFolder != null ? Colors.black : theme.colorScheme.onSurface,
                        fontSize: 7,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Button to choose lyrics folder
                Row(
                  children: [
                    Expanded(
                      child: RetroButton(
                        isCompact: true,
                        label: 'CHOOSE LRC FOLDER',
                        icon: RetroIcon('folder', size: 13, color: theme.colorScheme.onPrimary),
                        backgroundColor: theme.colorScheme.primary,
                        onPressed: () async {
                          try {
                            await PermissionHelper.requestStoragePermission();
                          } catch (_) {}

                          try {
                            final picked = await FilePickerPlatform.instance.getDirectoryPath();
                            if (picked != null && picked.isNotEmpty) {
                              final normalized = FileScannerService.normalizeFolderPath(picked);
                              await lyricsNotifier.setLocalLrcFolderPath(normalized);
                              if (mounted) {
                                RetroToast.show(
                                  context,
                                  'LYRICS DIRECTORY SET: ${normalized.split('/').last}',
                                  icon: 'folder',
                                  iconColor: theme.colorScheme.secondary,
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              RetroToast.show(context, 'PICKER ERROR: $e', icon: 'close');
                            }
                          }
                        },
                      ),
                    ),
                    if (customLrcFolder != null) ...[
                      const SizedBox(width: 8),
                      RetroButton(
                        isCompact: true,
                        label: 'RESET',
                        icon: RetroIcon('refresh', size: 13, color: theme.colorScheme.onSurface),
                        backgroundColor: retro.cardColor,
                        textColor: theme.colorScheme.onSurface,
                        borderColor: retro.borderColor,
                        onPressed: () async {
                          await lyricsNotifier.setLocalLrcFolderPath(null);
                          if (mounted) {
                            RetroToast.show(
                              context,
                              'RESET TO DEFAULT LYRICS SCANNING',
                              icon: 'refresh',
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

          const SizedBox(height: 12),

          // Features Tips
          _buildFeatureCard(
            theme,
            retro,
            const _FeatureItem(
              icon: 'check',
              title: 'AUTOMATIC TRACK MATCHING',
              description:
                  'Songs pair with .lrc files automatically when the filename matches the track title or audio file.',
            ),
          ),
          _buildFeatureCard(
            theme,
            retro,
            const _FeatureItem(
              icon: 'sliders',
              title: 'MILLIMETER TIME OFFSET',
              description:
                  'Use the live +/- offset buttons on the now playing screen to calibrate lyrics sync with millisecond precision.',
            ),
          ),
        ],
      ),
    );
  }

  // --- TOGGLE FETCH ALL & CONFIRMATION BOX ---
  Future<void> _handleToggleFetchAll(bool value) async {
    if (value) {
      await _showFetchAllConfirmationDialog();
    } else {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.setFetchAllAudio(false);
      setState(() => _fetchAllAudio = false);
      if (mounted) {
        RetroToast.show(
          context,
          'FETCH ALL AUDIO DISABLED',
          icon: 'close',
        );
      }
    }
  }

  Future<void> _showFetchAllConfirmationDialog() async {
    final theme = Theme.of(context);
    final retro = context.retro;

    final confirmed = await showDialog<bool>(
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
                'FETCH ALL AUDIO will scan all standard device folders (Music, Downloads, Audio, Podcasts).\n\nNotice: This may include non-music audio like voice recordings, WhatsApp audio, or system alert sounds.\n\nDo you want to enable Fetch All Audio?',
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

    if (confirmed == true && mounted) {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      await settingsRepo.setFetchAllAudio(true);
      if (!mounted) return;
      setState(() => _fetchAllAudio = true);
      RetroToast.show(
        context,
        'FETCH ALL AUDIO ENABLED',
        icon: 'check',
        iconColor: retro.accentGreen,
      );
    }
  }

  Widget _buildStageHero({
    required RetroThemeTokens retro,
    required String heroIcon,
    required Color heroIconColor,
    required String heroBadgeText,
    required Color heroBadgeColor,
    Color? heroBadgeTextColor,
    required String title,
    required String tagline,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: retro.cardColor,
            border: Border.all(color: retro.borderColor, width: 2.5),
            borderRadius: BorderRadius.zero,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 3,
                left: 3,
                child: Container(width: 4, height: 4, color: retro.borderColor),
              ),
              Positioned(
                top: 3,
                right: 3,
                child: Container(width: 4, height: 4, color: retro.borderColor),
              ),
              Positioned(
                bottom: 3,
                left: 3,
                child: Container(width: 4, height: 4, color: retro.borderColor),
              ),
              Positioned(
                bottom: 3,
                right: 3,
                child: Container(width: 4, height: 4, color: retro.borderColor),
              ),
              RetroIcon(heroIcon, size: 48, color: heroIconColor),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RetroBadge(
          text: heroBadgeText,
          backgroundColor: heroBadgeColor,
          textColor: heroBadgeTextColor ?? Colors.white,
          fontSize: 9,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          tagline,
          style: RetroTypography.retroMono(
            color: theme.colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(ThemeData theme, RetroThemeTokens retro, _FeatureItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RetroCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: retro.cardColor,
        borderColor: retro.borderColor,
        borderWidth: 1.8,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
                borderRadius: BorderRadius.zero,
              ),
              child: RetroIcon(
                item.icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageLayout({
    required ThemeData theme,
    required RetroThemeTokens retro,
    required String heroIcon,
    required Color heroIconColor,
    required String heroBadgeText,
    required Color heroBadgeColor,
    Color? heroBadgeTextColor,
    required String title,
    required String tagline,
    required List<_FeatureItem> features,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero Illustration Box
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border.all(color: retro.borderColor, width: 2.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Diagonal corner accents
                Positioned(
                  top: 3,
                  left: 3,
                  child: Container(width: 4, height: 4, color: retro.borderColor),
                ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(width: 4, height: 4, color: retro.borderColor),
                ),
                Positioned(
                  bottom: 3,
                  left: 3,
                  child: Container(width: 4, height: 4, color: retro.borderColor),
                ),
                Positioned(
                  bottom: 3,
                  right: 3,
                  child: Container(width: 4, height: 4, color: retro.borderColor),
                ),
                RetroIcon(heroIcon, size: 48, color: heroIconColor),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stage Badge
          RetroBadge(
            text: heroBadgeText,
            backgroundColor: heroBadgeColor,
            textColor: heroBadgeTextColor ?? Colors.white,
            fontSize: 9,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            title,
            style: RetroTypography.pixelHeader(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Tagline
          Text(
            tagline,
            style: RetroTypography.retroMono(
              color: theme.colorScheme.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Feature list cards
          ...features.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RetroCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                backgroundColor: retro.cardColor,
                borderColor: retro.borderColor,
                borderWidth: 1.8,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: RetroIcon(
                        item.icon,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.description,
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, RetroThemeTokens retro) {
    final isLastPage = _currentPage == _totalPages - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border(
          top: BorderSide(
            color: retro.borderColor,
            width: retro.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentPage > 0)
            RetroButton(
              isCompact: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              label: 'PREV',
              icon: const RetroIcon('arrow_left', size: 14),
              backgroundColor: retro.cardColor,
              textColor: theme.colorScheme.onSurface,
              borderColor: retro.borderColor,
              onPressed: _previousPage,
            )
          else
            const SizedBox(width: 60),

          const Spacer(),

          // Pixel Step Indicator Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_totalPages, (index) {
              final isCurrent = index == _currentPage;
              return Container(
                width: isCurrent ? 16 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.surface,
                  border: Border.all(
                    color: isCurrent ? theme.colorScheme.primary : retro.borderColor,
                    width: 1.8,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
              );
            }),
          ),

          const Spacer(),

          // Next or Start Button
          if (isLastPage)
            RetroButton(
              isCompact: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              label: 'PRESS START',
              icon: const RetroIcon('play', size: 14, color: Colors.black),
              backgroundColor: retro.accentGreen,
              textColor: Colors.black,
              borderColor: retro.borderColor,
              onPressed: _finishOnboarding,
            )
          else
            RetroButton(
              isCompact: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              label: 'NEXT',
              icon: RetroIcon('skip_next', size: 14, color: theme.colorScheme.onPrimary),
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
              borderColor: retro.borderColor,
              onPressed: _nextPage,
            ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final String icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
