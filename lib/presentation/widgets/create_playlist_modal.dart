import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import '../providers/playlist_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'retro_album_art.dart';
import 'retro_button.dart';
import 'retro_icon.dart';
import 'retro_toast.dart';
import '../screens/playlists/retro_image_editor_screen.dart';

class CreatePlaylistModal extends ConsumerStatefulWidget {
  final Song? initialSong;
  final bool isInitialEmptyPrompt;

  const CreatePlaylistModal({
    super.key,
    this.initialSong,
    this.isInitialEmptyPrompt = false,
  });

  /// Static helper to display the modal dialog
  static Future<Playlist?> show(
    BuildContext context, {
    Song? initialSong,
    bool isInitialEmptyPrompt = false,
  }) {
    return showDialog<Playlist>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CreatePlaylistModal(
        initialSong: initialSong,
        isInitialEmptyPrompt: isInitialEmptyPrompt,
      ),
    );
  }

  @override
  ConsumerState<CreatePlaylistModal> createState() => _CreatePlaylistModalState();
}

class _CreatePlaylistModalState extends ConsumerState<CreatePlaylistModal> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isCreating = false;
  String? _customCoverPath;

  static const List<String> _quickSuggestions = [
    'CHIPTUNES',
    '8-BIT HITS',
    'RETRO VIBES',
    'FAVORITES',
    'SYNTHWAVE',
    'LO-FI',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.image,
      );
      if (result.isNotEmpty) {
        final path = result.first.path;
        if (path != null && path.isNotEmpty) {
          if (!mounted) return;
          final editedPath = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => RetroImageEditorScreen(imagePath: path),
            ),
          );
          if (editedPath != null && editedPath.isNotEmpty) {
            setState(() => _customCoverPath = editedPath);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        RetroToast.show(context, 'COULD NOT SELECT IMAGE', icon: 'close');
      }
    }
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _isCreating) return;

    setState(() => _isCreating = true);

    try {
      final notifier = ref.read(playlistProvider.notifier);
      final newPlaylist = await notifier.createPlaylist(
        name,
        customArtPath: _customCoverPath,
      );

      if (widget.initialSong != null) {
        await notifier.addSongToPlaylist(newPlaylist.id, widget.initialSong!.id);
      }

      if (mounted) {
        Navigator.of(context).pop(newPlaylist);

        final message = widget.initialSong != null
            ? 'CREATED "${newPlaylist.name.toUpperCase()}" & ADDED TRACK!'
            : 'CREATED PLAYLIST "${newPlaylist.name.toUpperCase()}"!';

        RetroToast.show(
          context,
          message,
          icon: 'plus',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: context.isNothingTheme
            ? BorderRadius.circular(16)
            : BorderRadius.zero,
        side: context.isNothingTheme
            ? BorderSide(color: context.nothing.borderSubtle, width: 0.5)
            : BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              border: Border.all(
                color: context.isNothingTheme ? Colors.transparent : retro.borderColor,
                width: context.isNothingTheme ? 0 : 2.0,
              ),
              borderRadius: context.isNothingTheme
                  ? BorderRadius.circular(999)
                  : BorderRadius.zero,
            ),
            child: const Center(
              child: RetroIcon('plus', size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isInitialEmptyPrompt
                  ? (context.isNothingTheme ? 'Create First Playlist' : 'CREATE FIRST PLAYLIST')
                  : (context.isNothingTheme ? 'New Playlist' : 'NEW PLAYLIST'),
              style: context.isNothingTheme
                  ? NothingTypography.headline(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                    )
                  : RetroTypography.pixelHeader(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                    ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isInitialEmptyPrompt) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.isNothingTheme ? context.nothing.surfaceContainer : retro.cardColor,
                  border: Border.all(
                    color: context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor,
                    width: context.isNothingTheme ? 0.5 : 1.5,
                  ),
                  borderRadius: context.isNothingTheme ? BorderRadius.circular(10) : BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    RetroIcon('folder', size: 18, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No playlists yet! Create your first playlist to organize your tracks.',
                        style: context.isNothingTheme
                            ? NothingTypography.body(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                fontSize: 12,
                              )
                            : RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (widget.initialSong != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.isNothingTheme
                      ? context.nothing.accent.withValues(alpha: 0.12)
                      : retro.accentYellow.withValues(alpha: 0.15),
                  border: Border.all(
                    color: context.isNothingTheme ? context.nothing.accent : retro.accentYellow,
                    width: context.isNothingTheme ? 0.5 : 1.5,
                  ),
                  borderRadius: context.isNothingTheme ? BorderRadius.circular(10) : BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    RetroIcon(
                      'music',
                      size: 16,
                      color: context.isNothingTheme ? context.nothing.accent : theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADDING TRACK TO PLAYLIST:',
                            style: context.isNothingTheme
                                ? NothingTypography.tag(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  )
                                : RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 7.5,
                                  ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.initialSong!.title,
                            style: context.isNothingTheme
                                ? NothingTypography.title(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )
                                : RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 9.5,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Text(
              'PLAYLIST NAME',
              style: context.isNothingTheme
                  ? NothingTypography.tag(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    )
                  : RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 9,
                    ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              style: context.isNothingTheme
                  ? NothingTypography.body(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                    )
                  : RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 11,
                    ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'e.g. My Favorites',
                hintStyle: context.isNothingTheme
                    ? NothingTypography.body(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 14,
                      )
                    : RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 10,
                      ),
                filled: true,
                fillColor: context.isNothingTheme ? context.nothing.surfaceContainer : retro.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor,
                    width: context.isNothingTheme ? 0.5 : 2.0,
                  ),
                  borderRadius: context.isNothingTheme ? BorderRadius.circular(10) : BorderRadius.zero,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor,
                    width: context.isNothingTheme ? 0.5 : 2.0,
                  ),
                  borderRadius: context.isNothingTheme ? BorderRadius.circular(10) : BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: context.isNothingTheme ? 1.0 : 2.0,
                  ),
                  borderRadius: context.isNothingTheme ? BorderRadius.circular(10) : BorderRadius.zero,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const RetroIcon('close', size: 14),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),

            // Cover Image Selection Card
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.isNothingTheme ? context.nothing.surfaceContainer : retro.cardColor,
                border: Border.all(
                  color: context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor,
                  width: context.isNothingTheme ? 0.5 : 1.5,
                ),
                borderRadius: context.isNothingTheme ? BorderRadius.circular(10) : BorderRadius.zero,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _customCoverPath != null
                          ? Colors.transparent
                          : theme.colorScheme.surface,
                      border: Border.all(
                        color: context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor,
                        width: context.isNothingTheme ? 0.5 : 1.5,
                      ),
                      borderRadius: context.isNothingTheme ? BorderRadius.circular(8) : BorderRadius.zero,
                    ),
                    clipBehavior: context.isNothingTheme ? Clip.antiAlias : Clip.none,
                    child: _customCoverPath != null
                        ? RetroAlbumArt(
                            artPath: _customCoverPath,
                            width: 44,
                            height: 44,
                            borderWidth: 0,
                          )
                        : const Center(
                            child: RetroIcon('disc', size: 22),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customCoverPath != null
                              ? 'CUSTOM COVER SET'
                              : 'COVER IMAGE (OPTIONAL)',
                          style: context.isNothingTheme
                              ? NothingTypography.tag(
                                  color: theme.colorScheme.onSurface,
                                )
                              : RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 8.5,
                                ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _customCoverPath != null
                              ? 'Image chosen from device'
                              : 'If omitted, 1st song art is used',
                          style: context.isNothingTheme
                              ? NothingTypography.label(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                )
                              : RetroTypography.retroMono(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_customCoverPath != null) ...[
                    IconButton(
                      iconSize: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const RetroIcon('close', size: 14),
                      onPressed: () => setState(() => _customCoverPath = null),
                      tooltip: 'Remove cover image',
                    ),
                    const SizedBox(width: 6),
                  ],
                  RetroButton(
                    isCompact: true,
                    label: _customCoverPath != null ? 'CHANGE' : 'CHOOSE',
                    backgroundColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                    onPressed: _pickCoverImage,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'QUICK SUGGESTIONS',
              style: context.isNothingTheme
                  ? NothingTypography.tag(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    )
                  : RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 8,
                    ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickSuggestions.map((suggestion) {
                final isSelected = _controller.text.trim().toUpperCase() == suggestion;
                return GestureDetector(
                  onTap: () {
                    _controller.text = suggestion;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: suggestion.length),
                    );
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : (context.isNothingTheme ? context.nothing.surfaceContainer : retro.cardColor),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor),
                        width: context.isNothingTheme ? 0.5 : 1.5,
                      ),
                      borderRadius: context.isNothingTheme ? BorderRadius.circular(999) : BorderRadius.zero,
                    ),
                    child: Text(
                      suggestion,
                      style: context.isNothingTheme
                          ? NothingTypography.tag(
                              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            )
                          : RetroTypography.pixelBadge(
                              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                              fontSize: 8,
                            ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        RetroButton(
          isCompact: true,
          label: 'CANCEL',
          backgroundColor: retro.cardColor,
          textColor: theme.colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        RetroButton(
          isCompact: true,
          label: _isCreating ? 'CREATING...' : '+ CREATE',
          backgroundColor: _controller.text.trim().isNotEmpty && !_isCreating
              ? theme.colorScheme.primary
              : retro.cardColor,
          textColor: _controller.text.trim().isNotEmpty && !_isCreating
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          onPressed: _controller.text.trim().isNotEmpty && !_isCreating ? _submit : null,
        ),
      ],
    );
  }
}
