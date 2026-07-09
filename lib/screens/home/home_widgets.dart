import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../screens/games/game_widgets.dart';
import '../../widgets/app_ui.dart';

class ModeHeroCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final Color accent;
  final Widget? trailing;

  const ModeHeroCard({super.key, 
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.chips = const [],
    this.accent = AppPalette.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: accent.withValues(alpha: 0.34),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.panelElevated.withValues(alpha: 0.98),
          AppPalette.panelDeep.withValues(alpha: 0.98),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 28,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.12),
          blurRadius: 24,
          spreadRadius: -8,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = trailing != null && constraints.maxWidth < 430;
          final compact = constraints.maxWidth < 360;
          final textColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: safeOrbitron(
                  fontSize: compact ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: compact ? 2.0 : 2.4,
                  color: AppPalette.goldHighlight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: safeOrbitron(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: bodyFont(context).copyWith(
                  color: AppPalette.textMuted,
                  height: 1.35,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textColumn,
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: trailing,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: textColumn),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

class ModeInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const ModeInfoChip({super.key, 
    required this.icon,
    required this.label,
    this.color = AppPalette.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const SummaryMetricTile({super.key, 
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.panelSoft.withValues(alpha: 0.95),
            AppPalette.panelDeep.withValues(alpha: 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: safeOrbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: AppPalette.textSubtle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: safeOrbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavTabData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavTabData(
      {required this.icon, required this.activeIcon, required this.label});
}

class HomeModeConfig {
  final String title;
  final String subtitle;
  final String badge;
  final String assetPath;
  final Color accent;
  final Color accentSecondary;
  final VoidCallback onTap;

  const HomeModeConfig({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.assetPath,
    required this.accent,
    required this.accentSecondary,
    required this.onTap,
  });
}

/// Picks a styled fallback icon for a mode card when its art fails to load,
/// inferred from the asset path (AI → robot, Friend → handshake, Online →
/// globe, Levels → trophy).
IconData _fallbackIconForAsset(String path) {
  final p = path.toLowerCase();
  if (p.contains('friend')) return Icons.handshake_rounded;
  if (p.contains('online') || p.contains('money')) return Icons.public_rounded;
  if (p.contains('level')) return Icons.emoji_events_rounded;
  if (p.contains('ai')) return Icons.smart_toy_rounded;
  return Icons.videogame_asset_rounded;
}

class BigModeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String badge;
  final String assetPath;
  final Color accent;
  final Color accentSecondary;
  final VoidCallback onTap;

  const BigModeCard({super.key, 
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.assetPath,
    required this.accent,
    required this.accentSecondary,
    required this.onTap,
  });

  @override
  State<BigModeCard> createState() => _BigModeCardState();
}

class _BigModeCardState extends State<BigModeCard> {
  bool _pressed = false;
  late Color _glowColor;
  late Color _gradientColorA;
  late Color _gradientColorB;

  @override
  void initState() {
    super.initState();
    _computeColors();
  }

  @override
  void didUpdateWidget(BigModeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accent != widget.accent ||
        oldWidget.accentSecondary != widget.accentSecondary) {
      _computeColors();
    }
  }

  void _computeColors() {
    _glowColor = Color.lerp(widget.accent, widget.accentSecondary, 0.5)!;
    _gradientColorA = Color.lerp(AppPalette.homeSurface, widget.accent, 0.10)!;
    _gradientColorB =
        Color.lerp(AppPalette.homeSurface2, widget.accentSecondary, 0.14)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientColorA, _gradientColorB],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: widget.accent.withOpacity(_pressed ? 0.62 : 0.36),
            width: _pressed ? 1.4 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.34),
              blurRadius: 24,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: _glowColor.withOpacity(_pressed ? 0.18 : 0.12),
              blurRadius: _pressed ? 28 : 22,
              spreadRadius: -6,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            splashColor: widget.accent.withOpacity(0.08),
            highlightColor: widget.accent.withOpacity(0.04),
            onHighlightChanged: (pressed) {
              if (_pressed != pressed) {
                setState(() => _pressed = pressed);
              }
            },
            onTap: widget.onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 220 || constraints.maxHeight < 220;

                  return Stack(
                    children: [
                      Positioned(
                        top: -36,
                        right: -18,
                        child: CardAura(
                          color: widget.accent,
                          size: compact ? 116 : 140,
                        ),
                      ),
                      Positioned(
                        bottom: -52,
                        left: -28,
                        child: CardAura(
                          color: widget.accentSecondary,
                          size: compact ? 126 : 150,
                          opacity: _pressed ? 0.18 : 0.12,
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(_pressed ? 0.07 : 0.04),
                                Colors.transparent,
                                Colors.black.withOpacity(0.10),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 14,
                          compact ? 12 : 14,
                          compact ? 12 : 14,
                          compact ? 12 : 14,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 8 : 10,
                                    vertical: compact ? 5 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: widget.accent.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: widget.accent,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  widget.accent.withOpacity(0.45),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.badge,
                                        style: homeLabelFont(
                                          context,
                                          fontSize: compact ? 8.0 : 8.5,
                                          color: widget.accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_outward_rounded,
                                  size: compact ? 16 : 18,
                                  color: AppPalette.homeBody.withOpacity(0.72),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 5 : 7),
                            Expanded(
                              flex: 5,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(compact ? 6 : 8),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(compact ? 18 : 22),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.05),
                                      Colors.white.withOpacity(0.02),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: widget.accent.withOpacity(0.14),
                                  ),
                                ),
                                child: Image.asset(
                                  widget.assetPath,
                                  fit: BoxFit.contain,
                                  // Downsample large mode GIFs/PNGs on decode to
                                  // avoid "Could not create Impeller texture"
                                  // from oversized full-resolution source art.
                                  cacheWidth: 720,
                                  // Styled dark-glass fallback (the surrounding
                                  // Container already supplies the glass + glow)
                                  // — never a red broken-image box.
                                  errorBuilder: (context, error, stack) {
                                    if (kDebugMode) {
                                      debugPrint('[ASSET] load_failed '
                                          'path=${widget.assetPath} error=$error');
                                      debugPrint('[ASSET] fallback_used '
                                          'path=${widget.assetPath}');
                                    }
                                    return Center(
                                      child: Icon(
                                        _fallbackIconForAsset(widget.assetPath),
                                        color: widget.accent.withOpacity(0.6),
                                        size: 44,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 5 : 7),
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // FittedBox scales the title down on tight
                                  // layouts (Arabic / short card heights)
                                  // instead of overflowing.
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: homeOrbitron(
                                          fontSize: compact ? 15 : 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          color: AppPalette.homeTitle,
                                          height: 1.05,
                                          shadows: [
                                            Shadow(
                                              color: widget.accent.withOpacity(0.18),
                                              blurRadius: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 2 : 3),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: homeBodyFont(
                                          context,
                                          fontSize: compact ? 10 : 11,
                                          color: AppPalette.homeBody,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Extracted game screens (see imports at top) ──────────

// Store screens → lib/screens/store/store_page.dart
// Coins history → lib/screens/coins_history_page.dart

