# myMusic — Complete Technical Architecture & Project Details

> **Version:** 2.1.0+12 · **Platform:** Android & iOS (Flutter / Dart) · **Engine:** `just_audio` + `audio_service`  
> **Aesthetic:** Pure Retro 8-Bit & Industrial Arcade (Chunky Pixel Borders · Zero Shadow · Pixel Badges)  
> **AI Engine:** 100% On-Device Local Inference · **Physics:** 120Hz Natural Ballistic Momentum

---

## 1. Project Overview & Vision

**myMusic** is an audiophile-grade, offline-first local music player built with Flutter. It caters to music enthusiasts with massive FLAC and hi-res libraries who value bit-perfect sound reproduction, seamless playback, privacy, and an iconic **Retro 8-Bit / Industrial Arcade** aesthetic inspired by vintage hi-fi gear, CRT terminals, and classic gaming consoles.

### Core Architectural Pillars
1. **Zero-Compromise Audio Quality**: Real-time audio decoding and streaming (`just_audio`, `audio_service`, `audio_session`) operate on high-priority audio threads. No UI animation, background scan, or AI inference is ever allowed to block the audio pipeline or cause playback stutters.
2. **100% Local & Offline**: All metadata extraction, playlist management, lyrics rendering, and AI inference execute completely on-device. No telemetry, no remote tracking, and no external API dependencies during music playback.
3. **Single Unified Retro Design System**: A cohesive retro identity with chunky borders, pixelated badges, tactile buttons, and CRT-style readouts. All legacy liquid glass and multi-theme branching have been fully removed to ensure maximum rendering speed, zero shader overhead, and visual consistency.
4. **Silky Smooth 120Hz Ballistic Scrolling**: Natural momentum glide (`ScrollDecelerationRate.normal`) with unified scroll coordination in `NestedScrollView` and decoupled `ValueNotifier` scroll listeners, eliminating stopping animation chop and frame drops.
5. **Spotify-Style Advanced Queue Management**: Implements dynamic priority queue stacking (Swipe Right to Add to Queue creates a top-level priority queue; Swipe Left to Play Next inserts directly after the active track).
6. **On-Device Local DSP & Smart Tagging**: Offline isolate-based waveform feature extraction (RMS energy, zero-crossing rates) for automatic mood, genre, and energy classification without network calls.

---

## 2. Design System & Visual Aesthetics

The app exclusively uses the **Retro Design System** defined across `lib/core/theme/`:

### Visual Identity
* **Chunky 2.5px Solid Borders**: Every card, button, tab bar, and header is framed in bold, crisp retro borders (`borderWidth: 2.5`).
* **Zero Border Radius (`BorderRadius.zero`)**: Pure angular geometry without rounded corners or blur shaders.
* **No Drop Shadows**: Clean flat pixel art appearance with zero blur rendering overhead.

### Typography (`lib/core/theme/retro_typography.dart`)
Bundled offline font families ensure consistent rendering across all devices without relying on Google Fonts at runtime:
* **PressStart2P**: Iconic 8-bit retro arcade display font for headers, track indicators, and pixel badges.
* **VT323**: Classic CRT terminal dot-matrix font for digital timers, duration readouts, sample rates, and frequency displays.
* **Geist & GeistMono**: Clean monospace typography for song titles, technical audio metadata, and list view readouts.
* **Satoshi**: Modern geometric sans-serif for secondary dialogs and descriptions.

### Themes & Color Palettes (`lib/core/theme/retro_colors.dart`)
* **Dark Arcade (`#121212`)**: Deep charcoal background with crisp high-contrast white and arcade green accents.
* **Light Classic (`#F5F1E8`)**: Warm vintage paper/cream background with pitch-black chunky borders.
* **OLED Black (`#000000`)**: Pure `#000000` AMOLED-optimized dark mode for zero power draw on mobile displays.
* **Retro Amber (`#FFB000`)**: Warm CRT phosphor aesthetic with amber and sepia glows.
* **Cyberpunk Neon (`#8B5CF6` / `#06B6D4`)**: High-contrast dark violet and cyan accents for an electric terminal vibe.
* **Monet Dynamic Engine (`lib/core/theme/monet_engine.dart`)**: Dynamic palette generation extracted in real time from the active album cover artwork.

### Custom Retro Widgets (`lib/presentation/widgets/`)
* **`RetroCard`**: Solid container with 2.5px chunky borders, optional header badges, and crisp background fills.
* **`RetroButton`**: Tactile interactive button with immediate pressed state feedback and custom pixel icons.
* **`RetroBadge`**: Compact status badge rendered in `PressStart2P` font with sharp corners.
* **`RetroSlider` & `RetroVolumeSlider`**: Industrial segmented tactile sliders with real-time horizontal progress fill, immediate local drag tracking, and discrete seek commits on release.
* **`RetroSongTile`**: Fixed-height, high-performance song tile with swipe gestures, track numbering, hi-res badge, and context options.
* **`RetroCassetteArt`**: Animated vintage audio cassette with rotating spools responding to playback state and speed.
* **`RetroScanlineOverlay`**: Subtle CRT phosphor scanline texture overlay.
* **`RetroLoadingState` & `RetroRefreshIndicator`**: Custom dot-matrix loading spinners and pull-to-refresh animations.
* **`SmoothLyricsTicker` & `LyricsSweeper`**: Real-time syllable-by-syllable karaoke text-sweeping ticker.

---

## 3. Smooth 120Hz Scrolling & Physics Engine

Optimized for high-refresh-rate 120Hz displays with libraries containing 10,000+ tracks:

1. **Natural Ballistic Momentum (`ScrollDecelerationRate.normal`)**:
   * Configured in `_SmoothScrollBehavior` (`lib/main.dart`). Fling gestures decelerate along an organic, continuous exponential curve, gliding smoothly to a stop without abrupt halts, artificial friction walls, or choppy stopping animations.
2. **Coordinated Nested Scroll Physics**:
   * `AllSongsTab`, `AlbumsTab`, `ArtistsTab`, and `FoldersTab` use `AlwaysScrollableScrollPhysics()` inside the `NestedScrollView` body, delegating overscroll coordination to the parent controller and preventing bouncing collision stutter when scrolling stops near the top header.
3. **Decoupled Scroll State (`ValueNotifier`)**:
   * Scroll notifications (such as the scroll-to-top floating button and sticky header indicators) update dedicated `ValueNotifier<bool>` instances. This completely eliminates calling `setState()` on root screen widgets during active scroll flings, preventing layout passes and frame drops during deceleration.
4. **Fixed Item Extents & Repaint Boundaries**:
   * Song lists utilize fixed `itemExtent: 72.0` to eliminate dynamic layout measurement during high-velocity scrolls.
   * Every `RetroSongTile` is isolated in a `RepaintBoundary` to prevent individual playback animations from repainting the viewport.
5. **Fast Memory Caching for Artwork**:
   * Album cover artwork decodes with `memCacheWidth: 120` and `memCacheHeight: 120` constraints, ensuring full-size 3000x3000px FLAC scans are never loaded into tile image buffers.

---

## 4. Audio Engine & Playback Pipeline

### High-Resolution Audio Architecture
* **Core Player**: `just_audio` engine with hardware-accelerated decoding for FLAC, ALAC, WAV, AAC, and MP3.
* **Background Service**: `audio_service` (`AudioPlayerHandler` at `lib/data/services/audio_player_handler.dart`) wraps playback in a persistent foreground service on Android and an audio session on iOS.
* **Bit-Perfect Audio Session**: Configured via `audio_session` to handle audio focus ducking, phone calls, headset disconnect auto-pause, and noisy intents.

### Android System Notification Integration
* Displays album cover artwork, track title, artist name, playback position seekbar, play/pause, next, and previous buttons in the system notification drawer.
* **Custom Shuffle with Dot**: Toggle button in the notification drawer switches between standard shuffle off and an active shuffle state rendered with a custom vector asset (`ic_shuffle_dot.xml`), providing instant visual confirmation.
* **Loop Mode Cycle**: Single-tap cycling between Loop Off, Loop All, and Loop Current Track directly from the system notification.

### Spotify-Style Queue Architecture
Implemented in `AudioPlayerHandler` and `player_provider.dart`:
1. **Swipe Right — "Add to Queue"**:
   * Creates an independent priority queue stacked directly on top of the current playback list.
   * If the user queues additional tracks, they append to this active priority queue.
   * The player drains this priority queue first. Once all queued songs have played, playback seamlessly returns to the original album or playlist queue without losing playback position.
2. **Swipe Left — "Play Next"**:
   * Inserts the selected track immediately after the currently playing song in the active queue, guaranteeing it is the very next track played.
3. **Queue Reordering & Dismissal**:
   * Reorderable queue sheet with drag-and-drop handles and swipe-to-remove.

### 10-Band Equalizer & DSP
* **`EqualizerService` & `EqualizerProvider`**:
  * 10-band graphic equalizer with preamp gain controls.
  * Presets: *Flat, Bass Boost, Treble Boost, Rock, Pop, Jazz, Electronic, Vocal, Classical*.
  * Bass boost and virtualizer controls with persistent preset saving in Hive.
* **`SpatialAudioService` & `SpatialAudioProvider`**:
  * Crossfeed and binaural spatial room simulation for headphone listening.

---

## 5. Library & Media Management

### Local File Scanner (`lib/data/services/file_scanner_service.dart`)
* Scans internal and external storage folders using `audio_metadata_reader`.
* Extracts embedded ID3v2, Vorbis Comments, and FLAC metadata (sample rate, bit depth, bitrate, title, artist, album, genre, track number, year).
* Automatically extracts and caches embedded album cover art to disk.
* Supports folder blacklisting to ignore ringtones, voice notes, and game sound effects.

### Navigation & Views
* **All Songs Tab**: Instant alphabetical sorting, date added sorting, duration sorting, and fast scrollbar thumb.
* **Albums Tab**: Grid and list views of albums with multi-disc support and year grouping.
* **Artists Tab**: Artist catalogue view with discography breakdowns.
* **Folders Tab**: Direct filesystem hierarchy browser for users who organize music via directories.
* **Playlists Tab**: User-created playlists with custom names, descriptions, dynamic 4-art grid collage generation, and reordering.
* **Recently Played**: Automatically tracked listening history with timestamp tracking.

---

## 6. Real-Time Synchronized Lyrics Engine

Located in `lib/data/services/lyrics_service.dart` and `lib/presentation/screens/lyrics/`:
* **Embedded & External `.lrc` Support**: Reads embedded `USLT` / `SYLT` metadata tags and searches local `.lrc` files in the same directory as the audio file.
* **Word & Syllable-Level Timing**: Supports extended LRC format with inline syllable timestamps. If absent, synthesizes smooth interpolation across line duration.
* **Binary Search Position Lookup**: O(log N) fast timestamp lookup runs synchronously on playback ticks without lagging.
* **Interactive UI**: Tap any lyric line to jump playback directly to that timestamp; auto-scrolls active line to center with smooth spring physics.

---

## 7. On-Device Local DSP & Smart Library Tagging

### Pure-Dart DSP Auto-Tagger (`lib/data/services/library_tagger_service.dart`)
* Background isolate audio analysis examining windowed RMS energy and zero-crossing rates.
* Automatic classification of Mood (*Chill, Melancholy, Focus, High Energy, Euphoric*), Genre (*Lo-Fi, Acoustic, Classical, Electronic, Synthwave, Hip-Hop, Rock*), and estimated BPM.
* 100% offline, zero audio stutter, yielding between tracks.

---

## 8. Directory Architecture

Built using **Riverpod** with strict unidirectional data flow:

```
myMusic/
├── android/                             # Native Android configuration
│   └── app/src/main/res/drawable/
│       └── ic_shuffle_dot.xml           # Custom notification shuffle dot icon
├── assets/
│   ├── fonts/                           # Geist, GeistMono, PressStart2P, Satoshi, VT323
│   ├── icons/                           # Vector icons and app launcher artwork
│   └── album_art/                       # Default fallback album covers
├── lib/
│   ├── main.dart                        # Service registration, Hive init, app entrypoint, smooth scroll physics
│   ├── core/
│   │   ├── constants/
│   │   │   ├── ai_model_config.dart     # Hugging Face registry
│   │   │   └── app_constants.dart       # Storage keys, Hive box names & defaults
│   │   └── theme/
│   │       ├── monet_engine.dart        # Dynamic artwork color extraction
│   │       ├── retro_colors.dart        # CRT amber, dark arcade, and neon palettes
│   │       ├── retro_theme.dart         # Pure retro theme definitions & tokens
│   │       └── retro_typography.dart    # PressStart2P, VT323, Geist typography
│   ├── data/
│   │   ├── repositories/
│   │   │   ├── audio_repository.dart    # Song, album, artist queries
│   │   │   ├── playlist_repository.dart # Local playlist CRUD operations
│   │   │   └── settings_repository.dart # Preferences & toggle persistence
│   │   └── services/
│   │       ├── audio_player_handler.dart# AudioService background playback & queue
│   │       ├── equalizer_service.dart   # 10-band equalizer audio processing
│   │       ├── file_scanner_service.dart# Local storage media scanner
│   │       ├── huggingface_model_manager.dart # Streaming downloader & cache
│   │       ├── library_tagger_service.dart    # Background isolate DSP metadata tagger
│   │       ├── lyrics_service.dart      # Local .lrc parser & timestamp sync
│   │       ├── spatial_audio_service.dart     # Spatial virtualizer service
│   │       ├── storage_service.dart     # Hive database interface
│   │       └── system_volume_service.dart # Hardware volume event listener
│   ├── domain/
│   │   └── models/
│   │       ├── ai_song_tags.dart        # Classification tags model
│   │       ├── album.dart               # Album domain model
│   │       ├── artist.dart              # Artist domain model
│   │       ├── audio_quality.dart       # Audio quality & bitrate indicators
│   │       ├── lrc_model.dart           # Synchronized lyrics line & word models
│   │       ├── playlist.dart            # Playlist domain model
│   │       ├── recently_played_item.dart# Listening history record
│   │       └── song.dart                # Song model with metadata
│   └── presentation/
│       ├── providers/                   # Riverpod providers (player, queue, library, etc.)
│       ├── widgets/                     # Reusable retro-styled UI widgets (RetroCard, RetroSlider, etc.)
│       └── screens/
│           ├── home_scaffold.dart       # Bottom navigation scaffold
│           ├── library/                 # Songs, Albums, Artists, Folders tabs & detail views
│           ├── playlists/               # Playlists list & PlaylistDetailScreen
│           ├── search/                  # Real-time search with full-width bar
│           ├── now_playing/             # Fullscreen player with cassette visualizer & RetroSlider
│           ├── lyrics/                  # Fullscreen synchronized lyrics view
│           ├── equalizer/               # 10-band graphic equalizer screen
│           ├── spatial_audio/           # Spatial room emulation screen
│           └── settings/                # Settings screen with retro audio & appearance controls
└── test/                                # Comprehensive test suites
```

---

## 9. Quality Assurance & Test Coverage

The project maintains rigorous unit, widget, and integration tests:
* **`test/audio_player_handler_test.dart`**: Validates Spotify-style priority queue stacking, play-next insertions, loop/shuffle cycles, and queue state restoration.
* **`test/playlist_cover_test.dart`**: Tests dynamic 4-art collage rendering and fallback cover behavior when songs lack embedded artwork.
* **`test/ai_features_and_navigation_test.dart`**: Tests on-device AI model configuration, Hugging Face manager file sizing, and lyrics anticipatory lead timing.
* **`test/lrc_lyrics_test.dart`**: Verifies standard and syllable-level `.lrc` parsing, binary search seek lookup, and empty line handling.
* **`test/widget_retro_test.dart`**: Comprehensive widget tests covering Retro buttons, sliders, cards, badges, and layout behaviors.
* **Analyzer Guarantee**: Clean compilation passing `flutter analyze` with 0 errors and 0 warnings.
