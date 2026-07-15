import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_l10n.dart';
import '../../../core/app_theme.dart';
import '../../../models/arena/arena_chat_signal.dart';

typedef ArenaChatSubmit = FutureOr<void> Function(String text);

/// Compact message composer shared by Arena lobby and online gameplay.
class OnlineChatBar extends StatefulWidget {
  final ArenaChatSubmit onSend;
  final VoidCallback? onEmojiPressed;
  final ValueChanged<Object>? onError;
  final bool enabled;
  final bool showEmojiButton;
  final bool autofocus;
  final int maxLength;
  final Color accent;
  final EdgeInsetsGeometry margin;

  const OnlineChatBar({
    super.key,
    required this.onSend,
    this.onEmojiPressed,
    this.onError,
    this.enabled = true,
    this.showEmojiButton = true,
    this.autofocus = false,
    this.maxLength = ArenaChatSignal.maxMessageLength,
    this.accent = AppPalette.primary,
    this.margin = EdgeInsets.zero,
  }) : assert(maxLength > 0 && maxLength <= ArenaChatSignal.maxMessageLength);

  @override
  State<OnlineChatBar> createState() => _OnlineChatBarState();
}

class _OnlineChatBarState extends State<OnlineChatBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;

  bool get _canSend =>
      widget.enabled && !_sending && _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    final text = _controller.text.trim();
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppPalette.homePanelStrong.withValues(alpha: 0.96),
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.accent.withValues(alpha: 0.34),
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 330;
          return Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled && !_sending,
                  autofocus: widget.autofocus,
                  maxLength: widget.maxLength,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  keyboardType: TextInputType.text,
                  cursorColor: widget.accent,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(
                    color: AppPalette.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    hintText: l10n.typeMessageHint,
                    hintStyle: TextStyle(
                      color: AppPalette.textMuted.withValues(alpha: 0.70),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: widget.accent.withValues(alpha: 0.85),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 11,
                    ),
                    filled: true,
                    fillColor: AppPalette.panelDeep.withValues(alpha: 0.68),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppPalette.strokeSoft.withValues(alpha: 0.7),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppPalette.strokeSoft.withValues(alpha: 0.7),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: widget.accent.withValues(alpha: 0.82),
                        width: 1.2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppPalette.strokeSoft.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.showEmojiButton &&
                  widget.onEmojiPressed != null) ...<Widget>[
                const SizedBox(width: 6),
                _ChatBarButton(
                  tooltip: l10n.quickReactionsLabel,
                  icon: Icons.emoji_emotions_outlined,
                  accent: AppPalette.accentPurple,
                  enabled: widget.enabled && !_sending,
                  onTap: widget.onEmojiPressed!,
                ),
              ],
              const SizedBox(width: 6),
              _SendButton(
                label: l10n.sendLabel,
                compact: compact,
                busy: _sending,
                enabled: _canSend,
                accent: widget.accent,
                onTap: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChatBarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  const _ChatBarButton({
    required this.tooltip,
    required this.icon,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: enabled ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: accent.withValues(alpha: enabled ? 0.46 : 0.18),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accent.withValues(alpha: enabled ? 1 : 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final String label;
  final bool compact;
  final bool busy;
  final bool enabled;
  final Color accent;
  final VoidCallback onTap;

  const _SendButton({
    required this.label,
    required this.compact,
    required this.busy,
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: compact ? 44 : 84,
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: enabled
                  ? LinearGradient(
                      colors: <Color>[
                        accent,
                        AppPalette.primary2,
                      ],
                    )
                  : null,
              color: enabled
                  ? null
                  : AppPalette.strokeSoft.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: enabled
                    ? accent.withValues(alpha: 0.9)
                    : AppPalette.strokeSoft.withValues(alpha: 0.24),
              ),
              boxShadow: enabled
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.28),
                        blurRadius: 14,
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
                      color: AppPalette.text,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.send_rounded,
                        size: 17,
                        color: enabled
                            ? AppPalette.panelDeep
                            : AppPalette.textMuted.withValues(alpha: 0.45),
                      ),
                      if (!compact) ...<Widget>[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: enabled
                                  ? AppPalette.panelDeep
                                  : AppPalette.textMuted
                                      .withValues(alpha: 0.45),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
