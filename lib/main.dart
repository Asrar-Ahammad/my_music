import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/retro_theme.dart';
import 'data/services/audio_player_handler.dart';
import 'data/services/storage_service.dart';
import 'presentation/providers/player_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/onboarding_provider.dart';
import 'presentation/providers/palette_provider.dart';
import 'presentation/providers/font_provider.dart';
import 'presentation/screens/home_scaffold.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opt into 120Hz rendering — Flutter will use whatever the display supports
  // (ProMotion / LTPO adaptive rate). This also adjusts vsync timing.
  timeDilation = 1.0; // ensure no slow-mo

  // Optimize image cache capacity to prevent thrashing during fast list scrolling
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB
  PaintingBinding.instance.imageCache.maximumSize = 2000;

  // Initialize offline Hive storage
  final storageService = StorageService();
  await storageService.init();

  // Initialize audio service handler for system music player & lock screen controls
  AudioPlayerHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.retro.mymusic.channel.audio',
        androidNotificationChannelName: '8-Bit Retro Music Player',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'drawable/ic_notification',
      ),
    );
    await audioHandler.init();
  } catch (e) {
    debugPrint('AudioService.init fallback: $e');
    audioHandler = AudioPlayerHandler();
    await audioHandler.init();
  }

  runApp(
    ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const RetroMusicApp(),
    ),
  );
}

class RetroMusicApp extends ConsumerStatefulWidget {
  const RetroMusicApp({super.key});

  @override
  ConsumerState<RetroMusicApp> createState() => _RetroMusicAppState();
}

class _RetroMusicAppState extends ConsumerState<RetroMusicApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      ref.read(audioHandlerProvider).saveCurrentPlaybackState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final paletteState = ref.watch(paletteProvider);
    final activeFont = ref.watch(fontProvider);
    final onboardingCompleted = ref.watch(onboardingProvider);
    final lightTheme = RetroTheme.lightTheme(
      paletteId: paletteState.lightPaletteId,
      fontFamily: activeFont,
    );
    final darkTheme = RetroTheme.darkTheme(
      paletteId: paletteState.darkPaletteId,
      fontFamily: activeFont,
    );

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      color: Colors.black,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final theme = Theme.of(context);
        return ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: child ?? const SizedBox.shrink(),
        );
      },
      // High-refresh-rate scroll behaviour — BouncingScrollPhysics with tight
      // spring gives natural feel at 120Hz; gestures get elevated sampling.
      scrollBehavior: const _SmoothScrollBehavior(),
      home: onboardingCompleted ? const HomeScaffold() : const OnboardingScreen(),
    );
  }
}

/// Custom [ScrollBehavior] that forces high-frequency gesture sampling and
/// uses [BouncingScrollPhysics] everywhere for a silky 120Hz feel.
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
        decelerationRate: ScrollDecelerationRate.normal,
      );

  /// Enable pointer-device kinds (touch + stylus) for richer gesture tracking.
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}
