import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/theme/retro_image_filters.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_toast.dart';

/// Full retro image editor for cropping and applying retro filters to playlist covers.
class RetroImageEditorScreen extends StatefulWidget {
  final String imagePath;

  const RetroImageEditorScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<RetroImageEditorScreen> createState() => _RetroImageEditorScreenState();
}

class _RetroImageEditorScreenState extends State<RetroImageEditorScreen> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController = TransformationController();

  RetroImageFilter _selectedFilter = RetroImageFilter.normal;
  bool _enableScanlines = false;
  bool _isSaving = false;

  void _resetCrop() {
    setState(() {
      _transformController.value = Matrix4.identity();
      _selectedFilter = RetroImageFilter.normal;
      _enableScanlines = false;
    });
  }

  RetroFilterPreset get _currentPreset {
    return RetroFilterPreset.presets.firstWhere(
      (p) => p.filter == _selectedFilter,
      orElse: () => RetroFilterPreset.presets.first,
    );
  }

  Future<void> _applyCover() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Small pause to let any pending render settles
      await Future.delayed(const Duration(milliseconds: 60));

      final boundary = _cropAreaKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Crop frame not ready');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to generate image bytes');
      }

      final pngBytes = byteData.buffer.asUint8List();

      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'playlist_covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      final targetPath = p.join(
        coversDir.path,
        'cover_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final file = File(targetPath);
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.of(context).pop(targetPath);
      }
    } catch (e) {
      if (mounted) {
        RetroToast.show(context, 'FAILED TO SAVE COVER: $e', icon: 'close');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final currentPreset = _currentPreset;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            RetroButton(
              isCompact: true,
              label: 'CANCEL',
              icon: const RetroIcon('close', size: 12),
              backgroundColor: retro.cardColor,
              textColor: theme.colorScheme.onSurface,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'COVER EDITOR',
                textAlign: TextAlign.center,
                style: RetroTypography.pixelHeader(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RetroButton(
              isCompact: true,
              label: _isSaving ? 'SAVING' : 'APPLY',
              icon: _isSaving
                  ? null
                  : RetroIcon('check', size: 12, color: theme.colorScheme.onPrimary),
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
              onPressed: _isSaving ? null : _applyCover,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Compute ideal square crop viewport dimension
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;
            final cropSize = (availableWidth - 40)
                .clamp(180.0, availableHeight * 0.46)
                .toDouble();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Square Crop Viewport with Corner Crosshairs
                  Center(
                    child: Container(
                      width: cropSize,
                      height: cropSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(
                          color: retro.borderColor,
                          width: retro.borderWidth,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // RepaintBoundary capturing the exact 1:1 square crop
                          RepaintBoundary(
                            key: _cropAreaKey,
                            child: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Interactive Pan & Zoom Image
                                  InteractiveViewer(
                                    transformationController:
                                        _transformController,
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    clipBehavior: Clip.none,
                                    child: Center(
                                      child: _buildFilteredImage(currentPreset),
                                    ),
                                  ),

                                  // Scanline overlay if enabled
                                  if (_enableScanlines)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: const RetroScanlinesPainter(),
                                        ),
                                      ),
                                    ),

                                  // Pixel grid overlay if preset has pixelation
                                  if (currentPreset.hasPixelOverlay)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: const RetroPixelGridPainter(),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Decorative Corner Accents (non-captured overlay)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: IgnorePointer(
                              child: Text(
                                '+',
                                style: RetroTypography.pixelBadge(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IgnorePointer(
                              child: Text(
                                '+',
                                style: RetroTypography.pixelBadge(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: IgnorePointer(
                              child: Text(
                                '+',
                                style: RetroTypography.pixelBadge(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: IgnorePointer(
                              child: Text(
                                '+',
                                style: RetroTypography.pixelBadge(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Viewport helper instructions
                  Text(
                    'DRAG TO PAN • PINCH TO ZOOM',
                    style: RetroTypography.pixelBadge(
                      fontSize: 8,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Quick Action Controls: CRT SCANLINES & RESET
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RetroButton(
                        isCompact: true,
                        label: _enableScanlines ? 'SCANLINES: ON' : 'SCANLINES: OFF',
                        icon: const RetroIcon('vinyl', size: 12),
                        backgroundColor: _enableScanlines
                            ? theme.colorScheme.primary
                            : retro.cardColor,
                        textColor: _enableScanlines
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        onPressed: () {
                          setState(() {
                            _enableScanlines = !_enableScanlines;
                          });
                        },
                      ),
                      const SizedBox(width: 10),
                      RetroButton(
                        isCompact: true,
                        label: 'RESET',
                        icon: const RetroIcon('refresh', size: 12),
                        backgroundColor: retro.cardColor,
                        textColor: theme.colorScheme.onSurface,
                        onPressed: _resetCrop,
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 3. Retro Filter Selection Card
                  RetroCard(
                    title: 'RETRO FILTERS',
                    titleTrailing: RetroBadge(
                      text: currentPreset.label,
                      backgroundColor: theme.colorScheme.primary,
                      textColor: theme.colorScheme.onPrimary,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            currentPreset.description,
                            style: RetroTypography.retroMono(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: RetroFilterPreset.presets.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final preset = RetroFilterPreset.presets[index];
                              final isSelected =
                                  preset.filter == _selectedFilter;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedFilter = preset.filter;
                                  });
                                },
                                child: Container(
                                  width: 88,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                        : retro.cardColor,
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : retro.borderColor,
                                      width: isSelected ? 2.5 : 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Mini visual preview swatch
                                      _buildFilterMiniSwatch(preset),
                                      const SizedBox(height: 6),
                                      Text(
                                        preset.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: RetroTypography.pixelBadge(
                                          fontSize: 7,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilteredImage(RetroFilterPreset preset) {
    Widget imageWidget = Image.file(
      File(widget.imagePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade900,
        alignment: Alignment.center,
        child: Text(
          'IMAGE ERROR',
          style: RetroTypography.pixelBadge(fontSize: 9, color: Colors.white),
        ),
      ),
    );

    if (preset.matrix != null) {
      imageWidget = ColorFiltered(
        colorFilter: ColorFilter.matrix(preset.matrix!),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFilterMiniSwatch(RetroFilterPreset preset) {
    // Generate indicative 4-block mini palette for the filter
    List<Color> colors;
    switch (preset.filter) {
      case RetroImageFilter.normal:
        colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
        break;
      case RetroImageFilter.gameBoy:
        colors = [
          const Color(0xFF0F380F),
          const Color(0xFF306230),
          const Color(0xFF8BAC0F),
          const Color(0xFF9BBC0F),
        ];
        break;
      case RetroImageFilter.pixelNoir:
        colors = [
          Colors.black,
          Colors.grey.shade800,
          Colors.grey.shade400,
          Colors.white,
        ];
        break;
      case RetroImageFilter.vintageCrt:
        colors = [
          const Color(0xFF2E1F14),
          const Color(0xFF5E3A1A),
          const Color(0xFFB58A5A),
          const Color(0xFFE8D3B0),
        ];
        break;
      case RetroImageFilter.synthwave:
        colors = [
          const Color(0xFF240046),
          const Color(0xFF7B2CBF),
          const Color(0xFFFF007F),
          const Color(0xFF00F5D4),
        ];
        break;
      case RetroImageFilter.cassette:
        colors = [
          const Color(0xFF2B1700),
          const Color(0xFF8B4513),
          const Color(0xFFE29578),
          const Color(0xFFFFDDD2),
        ];
        break;
      case RetroImageFilter.cyberpunk:
        colors = [
          const Color(0xFF0D0221),
          const Color(0xFF540D6E),
          const Color(0xFFFFD166),
          const Color(0xFF06D6A0),
        ];
        break;
      case RetroImageFilter.pixelate:
        colors = [
          Colors.teal,
          Colors.cyan,
          Colors.amber,
          Colors.deepOrange,
        ];
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: colors.map((c) {
        return Container(
          width: 8,
          height: 12,
          color: c,
        );
      }).toList(),
    );
  }
}
