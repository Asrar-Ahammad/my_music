import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_icon.dart';

// ---------------------------------------------------------------------------
// Process-lifetime file-existence cache
// Avoids repeated synchronous or async disk probes for the same path.
// ---------------------------------------------------------------------------
class _FileExistenceCache {
  _FileExistenceCache._();
  static final _FileExistenceCache instance = _FileExistenceCache._();

  // Simple bounded map: evict oldest when over capacity.
  static const int _maxEntries = 2000;
  final Map<String, bool> _cache = {};
  final List<String> _insertionOrder = [];

  bool? get(String path) => _cache[path];

  void set(String path, bool exists) {
    if (_cache.containsKey(path)) return;
    if (_cache.length >= _maxEntries) {
      final oldest = _insertionOrder.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[path] = exists;
    _insertionOrder.add(path);
  }

  bool isKnownMissing(String path) => _cache[path] == false;

  bool checkSync(String path) {
    final cached = get(path);
    if (cached != null) return cached;
    try {
      final exists = File(path).existsSync();
      set(path, exists);
      return exists;
    } catch (_) {
      set(path, false);
      return false;
    }
  }

  Future<bool> checkAsync(String path) async {
    return checkSync(path);
  }
}

class RetroAlbumArt extends StatelessWidget {
  final String? artPath;
  final String? title;
  final String? artist;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double placeholderIconSize;
  final Color? placeholderColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final BorderRadius? borderRadius;

  const RetroAlbumArt({
    super.key,
    required this.artPath,
    this.title,
    this.artist,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIconSize = 24,
    this.placeholderColor,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
  });

  static const List<({Color bg, Color accent, Color groove})> _retroPalettes = [
    (bg: Color(0xFF260033), accent: Color(0xFFFF007F), groove: Color(0xFF4A0E5C)),
    (bg: Color(0xFF001F3F), accent: Color(0xFF00F5D4), groove: Color(0xFF073B4C)),
    (bg: Color(0xFF2B1700), accent: Color(0xFFFFB703), groove: Color(0xFF472600)),
    (bg: Color(0xFF0B2912), accent: Color(0xFF2EC4B6), groove: Color(0xFF134E23)),
    (bg: Color(0xFF1B003A), accent: Color(0xFF9D4EDD), groove: Color(0xFF380062)),
    (bg: Color(0xFF33000F), accent: Color(0xFFFF3366), groove: Color(0xFF5C001B)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final isNothing = context.isNothingTheme;
    final isModern = isNothing;

    final borderC = borderColor ??
        (isNothing ? context.nothing.borderColor : retro.borderColor);
    final borderW = borderWidth ?? (isNothing ? 0.5 : 0.0);
    final bgC = backgroundColor ??
        (isNothing ? theme.colorScheme.surface : retro.cardColor);
    final iconC = placeholderColor ?? theme.colorScheme.primary;

    final effectiveRadius = borderRadius ??
        BorderRadius.circular(
          isNothing ? ((width != null && width! > 100) ? 14.0 : 8.0) : 0.0,
        );

    // ── Placeholder ──────────────────────────────────────────────────────────
    Widget buildPlaceholder() {
      if (isNothing) {
        final initial = (title != null && title!.trim().isNotEmpty)
            ? title!.trim().substring(0, 1).toUpperCase()
            : null;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isNothing
                ? (theme.brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFE5E5E5))
                : bgC,
            borderRadius: effectiveRadius,
          ),
          child: Center(
            child: initial != null
                ? Text(
                    initial,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: (placeholderIconSize * 0.7).clamp(10.0, 24.0),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Icon(
                    Icons.music_note_rounded,
                    size: placeholderIconSize,
                    color: iconC,
                  ),
          ),
        );
      }

      if (title != null && title!.trim().isNotEmpty) {
        final palette = _retroPalettes[title!.hashCode.abs() % _retroPalettes.length];
        final initial = title!.trim().substring(0, 1).toUpperCase();

        return SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: palette.bg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: placeholderIconSize * 2.8,
                  height: placeholderIconSize * 2.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.groove, width: 2.0),
                  ),
                ),
                Container(
                  width: placeholderIconSize * 2.0,
                  height: placeholderIconSize * 2.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: palette.groove.withValues(alpha: 0.7), width: 1.5),
                  ),
                ),
                Container(
                  width: placeholderIconSize * 1.3,
                  height: placeholderIconSize * 1.3,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2.0),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: RetroTypography.pixelHeader(
                        color: Colors.black,
                        fontSize: (placeholderIconSize * 0.55).clamp(8.0, 18.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: bgC,
          child: Center(
            child: RetroIcon('music', size: placeholderIconSize, color: iconC),
          ),
        ),
      );
    }

    // ── Wrap with border / clip ───────────────────────────────────────────────
    Widget wrapWithBorder(Widget child) {
      if (isModern) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bgC,
            border: borderW > 0 ? Border.all(color: borderC, width: borderW) : null,
            borderRadius: effectiveRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      }
      if (borderW > 0) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bgC,
            border: Border.all(color: borderC, width: borderW),
            borderRadius: BorderRadius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      }
      if (width != null || height != null) {
        return SizedBox(width: width, height: height, child: child);
      }
      return child;
    }

    // ── Normalize path ────────────────────────────────────────────────────────
    String? normalizedPath = artPath?.trim();
    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      var clean = normalizedPath;
      if (clean.startsWith('file://')) {
        try {
          clean = Uri.parse(clean).toFilePath();
        } catch (_) {
          clean = clean.substring(7);
        }
      }
      try {
        clean = Uri.decodeComponent(clean);
      } catch (_) {}
      clean = clean.replaceAll('"', '').replaceAll("'", '').trim();

      if (clean.startsWith('/assets/')) {
        clean = clean.substring(1);
      } else if (!clean.startsWith('assets/') &&
          (clean.startsWith('album_art/') || clean.startsWith('icons/'))) {
        clean = 'assets/$clean';
      }
      normalizedPath = clean;
    }

    if (normalizedPath == null || normalizedPath.isEmpty) {
      return wrapWithBorder(buildPlaceholder());
    }

    final effectiveWidth = (width != null && width!.isFinite) ? width : null;
    final effectiveHeight = (height != null && height!.isFinite) ? height : null;

    final int targetCacheWidth = (width != null && width!.isFinite && width! > 0)
        ? (width! * 2.5).round().clamp(64, 640)
        : 256;
    final int targetCacheHeight = (height != null && height!.isFinite && height! > 0)
        ? (height! * 2.5).round().clamp(64, 640)
        : 256;

    // ── Network URL (e.g. artist photos from Deezer/iTunes) ──────────────────
    if (normalizedPath.startsWith('http://') || normalizedPath.startsWith('https://')) {
      final img = Image.network(
        normalizedPath,
        width: width,
        height: height,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return buildPlaceholder();
        },
      );
      return wrapWithBorder(img);
    }

    // ── Asset paths — always synchronous ─────────────────────────────────────
    if (normalizedPath.startsWith('assets/')) {
      Widget img;
      if (normalizedPath.toLowerCase().endsWith('.svg')) {
        img = SvgPicture.asset(
          normalizedPath,
          width: effectiveWidth,
          height: effectiveHeight,
          fit: fit,
          placeholderBuilder: (_) => buildPlaceholder(),
        );
      } else {
        img = Image.asset(
          normalizedPath,
          width: width,
          height: height,
          cacheWidth: targetCacheWidth,
          cacheHeight: targetCacheHeight,
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            return child;
          },
          errorBuilder: (_, _, _) => buildPlaceholder(),
        );
      }
      return wrapWithBorder(img);
    }

    // ── Local disk file — check known-missing without blocking UI thread ───────
    if (_FileExistenceCache.instance.isKnownMissing(normalizedPath)) {
      return wrapWithBorder(buildPlaceholder());
    }

    final fileObj = File(normalizedPath);
    Widget img;
    if (normalizedPath.toLowerCase().endsWith('.svg')) {
      img = SvgPicture.file(
        fileObj,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        placeholderBuilder: (_) => buildPlaceholder(),
      );
    } else {
      img = Image.file(
        fileObj,
        width: width,
        height: height,
        cacheWidth: targetCacheWidth,
        cacheHeight: targetCacheHeight,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return child;
        },
        errorBuilder: (_, _, _) {
          _FileExistenceCache.instance.set(normalizedPath!, false);
          return buildPlaceholder();
        },
      );
    }
    return wrapWithBorder(img);
  }

  /// Precaches album art into memory so that song transitions render cover art instantly.
  static void precacheArt(String? artPath, [BuildContext? context]) {
    if (artPath == null || artPath.trim().isEmpty) return;
    var clean = artPath.trim();
    if (clean.startsWith('file://')) {
      try {
        clean = Uri.parse(clean).toFilePath();
      } catch (_) {
        clean = clean.substring(7);
      }
    }
    clean = clean.replaceAll('"', '').replaceAll("'", '').trim();
    if (clean.startsWith('/assets/')) clean = clean.substring(1);
    if (clean.toLowerCase().endsWith('.svg')) return;

    final ImageProvider provider;
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      provider = ResizeImage(NetworkImage(clean), width: 300, height: 300);
    } else if (clean.startsWith('assets/')) {
      provider = ResizeImage(AssetImage(clean), width: 300, height: 300);
    } else {
      if (_FileExistenceCache.instance.isKnownMissing(clean)) return;
      provider = ResizeImage(FileImage(File(clean)), width: 300, height: 300);
    }

    if (context != null && context.mounted) {
      precacheImage(provider, context).catchError((_) {});
    } else {
      final stream = provider.resolve(const ImageConfiguration());
      stream.addListener(ImageStreamListener((_, _) {}, onError: (_, _) {}));
    }
  }
}
