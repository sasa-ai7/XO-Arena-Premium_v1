import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';
import '../../../models/game_emoji.dart';

typedef ArenaEmojiSelected = FutureOr<void> Function(String emoji);

/// Horizontally scrollable quick-reaction chips shared by lobby and gameplay.
class QuickEmojiBar extends StatefulWidget {
  final ArenaEmojiSelected onSelected;
  final ValueChanged<Object>? onError;
  final List<String> emojis;
  final bool enabled;
  final bool showLabel;
  final bool decorated;
  final EdgeInsetsGeometry margin;

  const QuickEmojiBar({
    super.key,
    required this.onSelected,
    this.onError,
    this.emojis = const <String>[],
    this.enabled = true,
    this.showLabel = true,
    this.decorated = true,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<QuickEmojiBar> createState() => _QuickEmojiBarState();
}

class _QuickEmojiBarState extends State<QuickEmojiBar> {
  // The chip showing a brief "busy" tick right after a tap. Cleared quickly so
  // it never blocks re-sending — including re-sending the SAME emoji.
  String? _sendingEmoji;
  // Short per-bar cooldown so a rapid double-tap can't spam, without holding a
  // lock for the whole network round-trip / animation.
  bool _cooldownActive = false;
  Timer? _cooldownTimer;
  static const int _uiCooldownMs = 3000;

  void _select(String emoji) {
    if (!widget.enabled) return;
    if (_cooldownActive) return;
    _cooldownActive = true;
    _cooldownTimer?.cancel();
    setState(() => _sendingEmoji = emoji);
    // Fire-and-forget: do not await, so the bar stays responsive and the same
    // emoji can be tapped again after the short cooldown to replay it.
    unawaited(() async {
      try {
        await widget.onSelected(emoji);
      } catch (error) {
        if (mounted && _cooldownActive) {
          _cooldownTimer?.cancel();
          setState(() {
            _cooldownActive = false;
            _sendingEmoji = null;
          });
        }
        widget.onError?.call(error);
      }
    }());
    _cooldownTimer = Timer(const Duration(milliseconds: _uiCooldownMs), () {
      if (!mounted) return;
      setState(() {
        _cooldownActive = false;
        _sendingEmoji = null;
      });
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // Fall back to the 5 free emojis when no equipped list is supplied.
    final ids =
        widget.emojis.isEmpty ? EmojiCatalog.defaultEquipped : widget.emojis;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.showLabel) ...<Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.bolt_rounded,
                size: 15,
                color: AppPalette.accentPurple,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.quickReactionsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
        ],
        SizedBox(
          height: 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Directionality(
              // Emoji order remains stable in both app languages.
              textDirection: TextDirection.ltr,
              child: Row(
                children: <Widget>[
                  for (var index = 0; index < ids.length; index++) ...<Widget>[
                    if (index > 0) const SizedBox(width: 8),
                    _EmojiChip(
                      emojiId: ids[index],
                      enabled: widget.enabled && !_cooldownActive,
                      busy: _sendingEmoji == ids[index],
                      semanticsLabel: l10n.quickReactionsLabel,
                      onTap: () => _select(ids[index]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!widget.decorated) {
      return Padding(padding: widget.margin, child: content);
    }
    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppPalette.homePanelStrong.withValues(alpha: 0.88),
            AppPalette.panelDeep.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppPalette.accentPurple.withValues(alpha: 0.28),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppPalette.accentPurple.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: -6,
          ),
        ],
      ),
      child: content,
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String emojiId;
  final bool enabled;
  final bool busy;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _EmojiChip({
    required this.emojiId,
    required this.enabled,
    required this.busy,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = EmojiCatalog.assetPathOf(emojiId);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 52,
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:
                  AppPalette.panelDeep.withValues(alpha: enabled ? 0.82 : 0.42),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    AppPalette.primary.withValues(alpha: enabled ? 0.30 : 0.12),
              ),
              boxShadow: enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppPalette.primary.withValues(alpha: 0.10),
                        blurRadius: 10,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppPalette.primary,
                    ),
                  )
                : Opacity(
                    opacity: enabled ? 1 : 0.4,
                    child: assetPath == null
                        ? Icon(Icons.emoji_emotions_outlined,
                            color: AppPalette.textMuted, size: 24)
                        : Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.broken_image_rounded,
                              color:
                                  AppPalette.textMuted.withValues(alpha: 0.6),
                              size: 22,
                            ),
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}
