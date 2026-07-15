import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/arena/arena_chat_signal.dart';
import '../../../models/game_emoji.dart';

/// Transient message/emoji bubble intended to sit beside a player avatar.
///
/// Persistent RTDB signals are hidden locally after [visibleFor], including
/// stale signals received when reopening a room. A changed signal nonce re-arms
/// the timer, so sending the same emoji twice still animates twice.
class PlayerReactionBubble extends StatefulWidget {
  final ArenaChatSignal? signal;
  final Duration visibleFor;
  final double maxWidth;
  final int messageMaxLines;
  final bool showSenderName;
  final Color accent;
  final AlignmentGeometry alignment;

  const PlayerReactionBubble({
    super.key,
    required this.signal,
    this.visibleFor = const Duration(seconds: 4),
    this.maxWidth = 190,
    this.messageMaxLines = 2,
    this.showSenderName = false,
    this.accent = AppPalette.primary,
    this.alignment = Alignment.center,
  })  : assert(maxWidth > 0),
        assert(messageMaxLines > 0);

  @override
  State<PlayerReactionBubble> createState() => _PlayerReactionBubbleState();
}

class _PlayerReactionBubbleState extends State<PlayerReactionBubble> {
  Timer? _hideTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _armTimer(notify: false);
  }

  @override
  void didUpdateWidget(covariant PlayerReactionBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSignal = oldWidget.signal;
    final nextSignal = widget.signal;
    if (oldSignal?.identity != nextSignal?.identity ||
        oldSignal?.effectiveSentAtMs != nextSignal?.effectiveSentAtMs ||
        oldWidget.visibleFor != widget.visibleFor) {
      _armTimer();
    }
  }

  void _armTimer({bool notify = true}) {
    _hideTimer?.cancel();
    _hideTimer = null;

    final signal = widget.signal;
    if (signal == null) {
      _setVisible(false, notify: notify);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final ageMs = now - signal.effectiveSentAtMs;
    // Emoji reactions stay visible for exactly 2s; text messages linger longer
    // so they can be read.
    final durationMs = signal.isEmoji ? 2000 : widget.visibleFor.inMilliseconds;
    if (signal.effectiveSentAtMs <= 0 ||
        ageMs >= durationMs ||
        ageMs < -60 * 1000) {
      _setVisible(false, notify: notify);
      return;
    }

    _setVisible(true, notify: notify);
    final remainingMs = durationMs - ageMs.clamp(0, durationMs);
    _hideTimer = Timer(Duration(milliseconds: remainingMs), () {
      if (!mounted) return;
      setState(() => _visible = false);
    });
  }

  void _setVisible(bool value, {required bool notify}) {
    if (_visible == value) return;
    if (notify && mounted) {
      setState(() => _visible = value);
    } else {
      _visible = value;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signal;
    return IgnorePointer(
      child: Align(
        alignment: widget.alignment,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 170),
          reverseDuration: const Duration(milliseconds: 160),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: !_visible || signal == null
              ? const SizedBox.shrink(key: ValueKey<String>('hidden'))
              : Semantics(
                  // Key includes the unique nonce + send time + emoji id so
                  // tapping the SAME emoji again always yields a new key and the
                  // AnimatedSwitcher remounts → the animation replays.
                  key: ValueKey<String>(
                      '${signal.identity}:${signal.effectiveSentAtMs}:${signal.payload}'),
                  liveRegion: true,
                  label: '${signal.senderName}: ${signal.payload}',
                  child: signal.isEmoji
                      ? _ImageEmojiReaction(
                          key: ValueKey<String>(
                            'emoji:${signal.identity}:'
                            '${signal.effectiveSentAtMs}:${signal.payload}',
                          ),
                          signal: signal,
                        )
                      : _MessageBubble(
                          signal: signal,
                          accent: widget.accent,
                          maxWidth: widget.maxWidth,
                          maxLines: widget.messageMaxLines,
                          showSenderName: widget.showSenderName,
                        ),
                ),
        ),
      ),
    );
  }
}

/// The image-only emoji reaction — no card/box/filter around it.
///
/// On appearance it pops in (scale), floats gently upward and fades near the
/// end of its life, then the parent [PlayerReactionBubble] removes it. A soft
/// drop shadow keeps it legible over the board without a container.
class _ImageEmojiReaction extends StatefulWidget {
  final ArenaChatSignal signal;

  const _ImageEmojiReaction({super.key, required this.signal});

  @override
  State<_ImageEmojiReaction> createState() => _ImageEmojiReactionState();
}

class _ImageEmojiReactionState extends State<_ImageEmojiReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _ImageEmojiReaction oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-run the pop/float animation whenever a new reaction replaces this one.
    if (oldWidget.signal.identity != widget.signal.identity) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = EmojiCatalog.assetPathOf(widget.signal.payload);
    final image = path == null
        ? const SizedBox.shrink()
        : Image.asset(
            path,
            key: ValueKey<String>(
              'asset:${widget.signal.identity}:'
              '${widget.signal.effectiveSentAtMs}:${widget.signal.payload}',
            ),
            width: 64,
            height: 64,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: false,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 64,
              height: 64,
              child: Icon(Icons.emoji_emotions_rounded,
                  color: AppPalette.textMuted, size: 40),
            ),
          );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Fast pop-in (~150ms) with a slight overshoot — snappy, not slow-mo.
        final popT = (t / 0.075).clamp(0.0, 1.0);
        final scale = Curves.easeOutBack.transform(popT);
        // Gentle upward drift across the ~2s life.
        final floatY = -16.0 * Curves.easeOut.transform(t);
        // Hold full opacity, then fade out over the final ~14% (~280ms).
        final opacity =
            t < 0.86 ? 1.0 : (1.0 - ((t - 0.86) / 0.14)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: image,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ArenaChatSignal signal;
  final Color accent;
  final double maxWidth;
  final int maxLines;
  final bool showSenderName;

  const _MessageBubble({
    required this.signal,
    required this.accent,
    required this.maxWidth,
    required this.maxLines,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final direction = _directionFor(signal.payload);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(AppPalette.homePanelStrong, accent, 0.10)!,
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.54), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.24),
            blurRadius: 16,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Directionality(
        textDirection: direction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showSenderName) ...<Widget>[
              Text(
                signal.senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              signal.payload,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: direction == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.left,
              style: const TextStyle(
                color: AppPalette.text,
                fontSize: 12.5,
                height: 1.28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TextDirection _directionFor(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
}
