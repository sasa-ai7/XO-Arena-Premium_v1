import 'package:flutter/material.dart';

import '../core/coin_format.dart';
import '../core/app_theme.dart';
import '../core/responsive_metrics.dart';
import '../models/game_avatar.dart';
import 'app_ui.dart';
import 'full_avatar_display.dart';

class AvatarStoreTab extends StatelessWidget {
  final List<int> ownedAvatars;
  final int equippedAvatar;
  final bool busy;
  final Future<void> Function(GameAvatar avatar) onBuyAvatar;
  final Future<void> Function(int id) onEquipAvatar;

  const AvatarStoreTab({
    super.key,
    required this.ownedAvatars,
    required this.equippedAvatar,
    required this.busy,
    required this.onBuyAvatar,
    required this.onEquipAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics =
            UiMetrics.of(constraints, MediaQuery.orientationOf(context));
        final spacing = metrics.cardGap;
        final horizontalPadding = metrics.horizontalPadding;
        final childAspectRatio = metrics.storeCardAspectRatio;
        final cardPadding = EdgeInsets.fromLTRB(
          metrics.sizeClass == DeviceSizeClass.compact ? 9 : 10,
          metrics.sizeClass == DeviceSizeClass.compact ? 9 : 10,
          metrics.sizeClass == DeviceSizeClass.compact ? 9 : 10,
          metrics.sizeClass == DeviceSizeClass.compact ? 11 : 12,
        );
        final buttonHeight = metrics.buttonHeight;

        final ownedSet = Set<int>.from(ownedAvatars);

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            14,
            horizontalPadding,
            18,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: kGameAvatars.length,
          itemBuilder: (context, index) {
            final avatar = kGameAvatars[index];
            final owned = ownedSet.contains(avatar.id);
            final equipped = equippedAvatar == avatar.id;
            final meta = _AvatarPresentation.forAvatar(avatar);

            return AppGlassCard(
          padding: cardPadding,
          radius: metrics.cardRadius,
          backgroundColor: equipped
              ? Color.lerp(AppPalette.panelElevated, const Color(0xFF3DCC6E), 0.28)
              : AppPalette.panel,
          borderColor: equipped
              ? const Color(0xFF3DCC6E).withOpacity(0.88)
              : meta.color.withOpacity(owned ? 0.40 : 0.26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: equipped
                  ? const Color(0xFF3DCC6E).withOpacity(0.48)
                  : meta.color.withOpacity(owned ? 0.14 : 0.10),
              blurRadius: equipped ? 36 : 22,
              spreadRadius: equipped ? -1 : -4,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RarityBadge(meta: meta),
                  const Spacer(),
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: meta.color.withOpacity(0.82),
                  ),
                ],
              ),
              SizedBox(height: spacing * 0.45),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(metrics.cardRadius - 2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.white.withOpacity(0.015),
                      ],
                    ),
                    border: Border.all(color: meta.color.withOpacity(0.16)),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -14,
                        right: -14,
                        child: _AvatarAura(
                          color: meta.color,
                          size: 100,
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, previewConstraints) {
                          final previewSize = (previewConstraints.biggest.shortestSide * 1.03)
                              .clamp(120.0, 280.0);
                          return Center(
                            child: FullAvatarDisplay(
                              size: previewSize,
                              avatar: avatar,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing * 0.45),
              Text(
                avatar.name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: safeOrbitron(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: bodyFont(context).copyWith(
                  fontSize: 11.5,
                  color: AppPalette.textMuted,
                  height: 1.2,
                ),
              ),
              SizedBox(height: spacing * 0.45),
              SizedBox(
                height: buttonHeight,
                child: _AvatarActionButton(
                  avatar: avatar,
                  meta: meta,
                  owned: owned,
                  equipped: equipped,
                  busy: busy,
                  onBuyAvatar: onBuyAvatar,
                  onEquipAvatar: onEquipAvatar,
                  metrics: metrics,
                ),
              ),
            ],
          ),
            );
          },
        );
      },
    );
  }
}

Future<bool?> showAvatarPurchaseDialog(BuildContext context, GameAvatar avatar) {
  final meta = _AvatarPresentation.forAvatar(avatar);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Purchase Avatar',
    barrierColor: Colors.black.withOpacity(0.76),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (ctx, a1, a2, child) {
      return FadeTransition(
        opacity: a1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.easeOutBack),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Colors.transparent,
              child: AppGlassCard(
                padding: const EdgeInsets.all(24),
                radius: 30,
                borderColor: meta.color.withOpacity(0.34),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: meta.color.withOpacity(0.14),
                    blurRadius: 26,
                    spreadRadius: -8,
                  ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RarityBadge(meta: meta),
                    const SizedBox(height: 16),
                    FullAvatarDisplay(
                      size: 128,
                      avatar: avatar,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      avatar.name.toUpperCase(),
                      style: safeOrbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      meta.subtitle,
                      style: bodyFont(context).copyWith(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppPalette.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppPalette.gold.withOpacity(0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/coin/COIN.png',
                            height: 18,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            avatar.price == 0 ? 'FREE UNLOCK' : '${avatar.price} XO COINS',
                            style: safeOrbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.goldHighlight,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: AppPillButton(
                            label: 'CANCEL',
                            fill: Colors.white.withOpacity(0.06),
                            stroke: AppPalette.strokeStrong,
                            onPressed: () => Navigator.of(ctx).pop(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPillButton(
                            label: avatar.price == 0 ? 'CLAIM' : 'CONFIRM',
                            fill: avatar.price == 0 ? AppPalette.primary2 : AppPalette.goldDeep,
                            stroke: avatar.price == 0
                                ? AppPalette.primary.withOpacity(0.45)
                                : AppPalette.goldHighlight.withOpacity(0.55),
                            onPressed: () => Navigator.of(ctx).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

String _formatBuyCoinsLabel(int value) {
  if (value >= 1000) {
    final compact = value / 1000;
    final fixed =
        compact % 1 == 0 ? compact.toStringAsFixed(0) : compact.toStringAsFixed(1);
    final normalized =
        fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
    return 'BUY ${normalized}K';
  }
  return 'BUY ${formatCoins(value)}';
}

class _AvatarActionButton extends StatelessWidget {
  final GameAvatar avatar;
  final _AvatarPresentation meta;
  final bool owned;
  final bool equipped;
  final bool busy;
  final Future<void> Function(GameAvatar avatar) onBuyAvatar;
  final Future<void> Function(int id) onEquipAvatar;
  final UiMetrics metrics;

  const _AvatarActionButton({
    required this.avatar,
    required this.meta,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.onBuyAvatar,
    required this.onEquipAvatar,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    if (equipped) {
      return AppPillButton(
        label: 'EQUIPPED',
        fill: const Color(0xFF3DCC6E),
        stroke: const Color(0xFF3DCC6E).withOpacity(0.55),
        onPressed: null,
        icon: Icons.check_rounded,
        labelFontSize: metrics.buttonFontSize,
        labelLetterSpacing: metrics.buttonLetterSpacing,
      );
    }

    if (owned) {
      return AppPillButton(
        label: 'EQUIP',
        fill: Colors.white.withOpacity(0.04),
        stroke: meta.color.withOpacity(0.42),
        onPressed: busy ? null : () => onEquipAvatar(avatar.id),
        icon: Icons.bolt_rounded,
        iconColor: meta.color,
        labelFontSize: metrics.buttonFontSize,
        labelLetterSpacing: metrics.buttonLetterSpacing,
      );
    }

    if (avatar.price == 0) {
      return AppPillButton(
        label: 'UNLOCK FREE',
        fill: AppPalette.primary2,
        stroke: AppPalette.primary.withOpacity(0.42),
        onPressed: busy ? null : () => onBuyAvatar(avatar),
        icon: Icons.card_giftcard_rounded,
        fitLabel: true,
        labelFontSize: metrics.buttonFontSize,
        labelLetterSpacing: metrics.buttonLetterSpacing,
      );
    }

    return AppPillButton(
      label: _formatBuyCoinsLabel(avatar.price),
      fill: AppPalette.goldDeep,
      stroke: AppPalette.goldHighlight.withOpacity(0.54),
      onPressed: busy ? null : () => onBuyAvatar(avatar),
      leading: Image.asset(
        'assets/coin/COIN.png',
        height: 14,
        fit: BoxFit.contain,
      ),
      leadingSlotWidth: 16,
      minHeight: metrics.buttonHeight,
      fitLabel: true,
      labelFontSize: metrics.buttonFontSize,
      labelLetterSpacing: metrics.buttonLetterSpacing,
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final _AvatarPresentation meta;

  const _RarityBadge({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.color.withOpacity(0.24)),
      ),
      child: Text(
        meta.rarity.toUpperCase(),
        style: homeLabelFont(
          context,
          fontSize: 7.5,
          color: meta.color,
        ),
      ),
    );
  }
}

class _AvatarAura extends StatelessWidget {
  final Color color;
  final double size;

  const _AvatarAura({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.04),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _AvatarPresentation {
  final String rarity;
  final String subtitle;
  final Color color;

  const _AvatarPresentation({
    required this.rarity,
    required this.subtitle,
    required this.color,
  });

  factory _AvatarPresentation.forAvatar(GameAvatar avatar) {
    switch (avatar.id) {
      case 1:
        return const _AvatarPresentation(
          rarity: 'Common',
          subtitle: 'Starter collectible frame',
          color: AppPalette.rarityCommon,
        );
      case 2:
        return const _AvatarPresentation(
          rarity: 'Common',
          subtitle: 'Synchronized arena presence',
          color: AppPalette.rarityCommon,
        );
      case 3:
        return const _AvatarPresentation(
          rarity: 'Legendary',
          subtitle: 'Apex strength embodied',
          color: AppPalette.rarityLegendary,
        );
      case 4:
        return const _AvatarPresentation(
          rarity: 'Rare',
          subtitle: 'Cryo-tuned arena skin',
          color: AppPalette.rarityRare,
        );
      case 5:
        return const _AvatarPresentation(
          rarity: 'Rare',
          subtitle: 'Powerful atmospheric frame',
          color: AppPalette.rarityRare,
        );
      case 6:
        return const _AvatarPresentation(
          rarity: 'Epic',
          subtitle: 'Shadow-tier premium collectible',
          color: AppPalette.rarityEpic,
        );
      case 7:
        return const _AvatarPresentation(
          rarity: 'Animated',
          subtitle: 'Reactive premium arena frame',
          color: AppPalette.rarityAnimated,
        );
      case 8:
        return const _AvatarPresentation(
          rarity: 'Animated',
          subtitle: 'Celestial collector showcase',
          color: AppPalette.rarityAnimated,
        );
      case 9:
        return const _AvatarPresentation(
          rarity: 'Epic',
          subtitle: 'Cosmic shadow collector',
          color: AppPalette.rarityEpic,
        );
      case 10:
        return const _AvatarPresentation(
          rarity: 'Animated',
          subtitle: 'Reactive premium arena frame',
          color: AppPalette.rarityAnimated,
        );
      default:
        return const _AvatarPresentation(
          rarity: 'Rare',
          subtitle: 'Premium collectible frame',
          color: AppPalette.rarityRare,
        );
    }
  }
}
