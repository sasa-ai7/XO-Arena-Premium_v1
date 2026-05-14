import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
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
        final nonGifAvatars = kGameAvatars.where((a) => !a.isGif).toList();
        final gifAvatars = kGameAvatars.where((a) => a.isGif).toList();

        final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        );

        final edgePadding = EdgeInsets.symmetric(horizontal: horizontalPadding);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 0),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final avatar = nonGifAvatars[index];
                    final owned = ownedSet.contains(avatar.id);
                    final equipped = equippedAvatar == avatar.id;
                    final meta = _AvatarPresentation.forAvatar(avatar);
                    return _AvatarCard(
                      avatar: avatar,
                      meta: meta,
                      owned: owned,
                      equipped: equipped,
                      busy: busy,
                      cardPadding: cardPadding,
                      metrics: metrics,
                      spacing: spacing,
                      onBuyAvatar: onBuyAvatar,
                      onEquipAvatar: onEquipAvatar,
                    );
                  },
                  childCount: nonGifAvatars.length,
                ),
                gridDelegate: gridDelegate,
              ),
            ),

            // Legendary Animated section header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPadding, spacing * 1.5, horizontalPadding, spacing * 0.6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppPalette.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppPalette.gold.withOpacity(0.40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: AppPalette.gold, size: 12),
                          const SizedBox(width: 6),
                          Text(
                            AppL10n.of(context).legendaryAnimated,
                            style: safeOrbitron(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              color: AppPalette.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppPalette.gold.withOpacity(0.36),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 18),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final avatar = gifAvatars[index];
                    final owned = ownedSet.contains(avatar.id);
                    final equipped = equippedAvatar == avatar.id;
                    final meta = _AvatarPresentation.forAvatar(avatar);
                    return _AvatarCard(
                      avatar: avatar,
                      meta: meta,
                      owned: owned,
                      equipped: equipped,
                      busy: busy,
                      cardPadding: cardPadding,
                      metrics: metrics,
                      spacing: spacing,
                      onBuyAvatar: onBuyAvatar,
                      onEquipAvatar: onEquipAvatar,
                      isGoldCard: true,
                    );
                  },
                  childCount: gifAvatars.length,
                ),
                gridDelegate: gridDelegate,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AvatarCard extends StatelessWidget {
  final GameAvatar avatar;
  final _AvatarPresentation meta;
  final bool owned;
  final bool equipped;
  final bool busy;
  final EdgeInsets cardPadding;
  final UiMetrics metrics;
  final double spacing;
  final Future<void> Function(GameAvatar) onBuyAvatar;
  final Future<void> Function(int) onEquipAvatar;
  final bool isGoldCard;

  const _AvatarCard({
    required this.avatar,
    required this.meta,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.cardPadding,
    required this.metrics,
    required this.spacing,
    required this.onBuyAvatar,
    required this.onEquipAvatar,
    this.isGoldCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final goldColor = AppPalette.gold;
    final borderColor = equipped
        ? const Color(0xFF3DCC6E).withOpacity(0.88)
        : isGoldCard
            ? goldColor.withOpacity(0.70)
            : meta.color.withOpacity(owned ? 0.40 : 0.26);

    final bgColor = equipped
        ? Color.lerp(AppPalette.panelElevated, const Color(0xFF3DCC6E), 0.28)
        : isGoldCard
            ? const Color(0xFF1A1200)
            : AppPalette.panel;

    return AppGlassCard(
      padding: cardPadding,
      radius: metrics.cardRadius,
      backgroundColor: bgColor,
      borderColor: borderColor,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.30),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: equipped
              ? const Color(0xFF3DCC6E).withOpacity(0.48)
              : isGoldCard
                  ? goldColor.withOpacity(0.22)
                  : meta.color.withOpacity(owned ? 0.14 : 0.10),
          blurRadius: equipped ? 36 : (isGoldCard ? 28 : 22),
          spreadRadius: equipped ? -1 : -4,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _RarityBadge(meta: meta, isGold: isGoldCard),
              const Spacer(),
              Icon(
                isGoldCard ? Icons.stars_rounded : Icons.auto_awesome,
                size: 16,
                color: isGoldCard
                    ? goldColor.withOpacity(0.90)
                    : meta.color.withOpacity(0.82),
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
                  colors: isGoldCard
                      ? [
                          goldColor.withOpacity(0.08),
                          Colors.black.withOpacity(0.30),
                        ]
                      : [
                          Colors.white.withOpacity(0.05),
                          Colors.white.withOpacity(0.015),
                        ],
                ),
                border: Border.all(
                  color: isGoldCard
                      ? goldColor.withOpacity(0.22)
                      : meta.color.withOpacity(0.16),
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Stack(
                children: [
                  Positioned(
                    top: -14,
                    right: -14,
                    child: _AvatarAura(
                      color: isGoldCard ? goldColor : meta.color,
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
              color: isGoldCard ? AppPalette.goldHighlight : Colors.white,
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
            height: metrics.buttonHeight,
            child: _AvatarActionButton(
              avatar: avatar,
              meta: meta,
              owned: owned,
              equipped: equipped,
              busy: busy,
              onBuyAvatar: onBuyAvatar,
              onEquipAvatar: onEquipAvatar,
              metrics: metrics,
              isGold: isGoldCard,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showAvatarPurchaseDialog(BuildContext context, GameAvatar avatar) {
  final meta = _AvatarPresentation.forAvatar(avatar);
  final isGif = avatar.isGif;
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
      final l10n = AppL10n.of(ctx);
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
                backgroundColor: isGif ? const Color(0xFF1A1200) : null,
                borderColor: isGif
                    ? AppPalette.gold.withOpacity(0.50)
                    : meta.color.withOpacity(0.34),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color: isGif
                        ? AppPalette.gold.withOpacity(0.18)
                        : meta.color.withOpacity(0.14),
                    blurRadius: 26,
                    spreadRadius: -8,
                  ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RarityBadge(meta: meta, isGold: isGif),
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
                        color: isGif ? AppPalette.goldHighlight : Colors.white,
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
                            avatar.price == 0
                                ? l10n.freeUnlockLabel
                                : l10n.xoCoinPrice(formatCoins(avatar.price)),
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
                            label: l10n.cancelBtn,
                            fill: Colors.white.withOpacity(0.06),
                            stroke: AppPalette.strokeStrong,
                            onPressed: () => Navigator.of(ctx).pop(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppPillButton(
                            label: avatar.price == 0 ? l10n.claimBtn : l10n.confirmBtn,
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

class _AvatarActionButton extends StatelessWidget {
  final GameAvatar avatar;
  final _AvatarPresentation meta;
  final bool owned;
  final bool equipped;
  final bool busy;
  final Future<void> Function(GameAvatar avatar) onBuyAvatar;
  final Future<void> Function(int id) onEquipAvatar;
  final UiMetrics metrics;
  final bool isGold;

  const _AvatarActionButton({
    required this.avatar,
    required this.meta,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.onBuyAvatar,
    required this.onEquipAvatar,
    required this.metrics,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (equipped) {
      // Tap "Equipped" to unequip (toggle off).
      return AppPillButton(
        label: l10n.storeEquipped,
        fill: const Color(0xFF3DCC6E),
        stroke: const Color(0xFF3DCC6E).withOpacity(0.55),
        onPressed: busy ? null : () => onEquipAvatar(0), // 0 = unequip
        icon: Icons.check_rounded,
        labelFontSize: metrics.buttonFontSize,
        labelLetterSpacing: metrics.buttonLetterSpacing,
      );
    }

    if (owned) {
      return AppPillButton(
        label: l10n.storeEquip,
        fill: Colors.white.withOpacity(0.04),
        stroke: isGold
            ? AppPalette.gold.withOpacity(0.55)
            : meta.color.withOpacity(0.42),
        onPressed: busy ? null : () => onEquipAvatar(avatar.id),
        icon: Icons.bolt_rounded,
        iconColor: isGold ? AppPalette.goldHighlight : meta.color,
        labelFontSize: metrics.buttonFontSize,
        labelLetterSpacing: metrics.buttonLetterSpacing,
      );
    }

    if (avatar.price == 0) {
      return AppPillButton(
        label: l10n.unlockFreeLabel,
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
      label: l10n.buyWithPrice(formatCoins(avatar.price)),
      fill: isGold ? AppPalette.goldDeep : AppPalette.goldDeep,
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
  final bool isGold;

  const _RarityBadge({required this.meta, this.isGold = false});

  @override
  Widget build(BuildContext context) {
    final color = isGold ? AppPalette.gold : meta.color;
    final l10n = AppL10n.of(context);
    final String rarityLabel;
    switch (meta.rarity) {
      case 'Legendary': rarityLabel = l10n.rarityLegendary; break;
      case 'Epic':      rarityLabel = l10n.rarityEpic;      break;
      case 'Animated':  rarityLabel = l10n.rarityAnimated;  break;
      default:          rarityLabel = meta.rarity;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Text(
        rarityLabel.toUpperCase(),
        style: homeLabelFont(
          context,
          fontSize: 7.5,
          color: color,
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
          rarity: 'Legendary',
          subtitle: 'Elite collector arena frame',
          color: AppPalette.rarityLegendary,
        );
      case 2:
        return const _AvatarPresentation(
          rarity: 'Legendary',
          subtitle: 'Synchronized arena presence',
          color: AppPalette.rarityLegendary,
        );
      case 3:
        return const _AvatarPresentation(
          rarity: 'Legendary',
          subtitle: 'Apex strength embodied',
          color: AppPalette.rarityLegendary,
        );
      case 4:
        return const _AvatarPresentation(
          rarity: 'Epic',
          subtitle: 'Cryo-tuned arena skin',
          color: AppPalette.rarityEpic,
        );
      case 5:
        return const _AvatarPresentation(
          rarity: 'Legendary',
          subtitle: 'Powerful atmospheric frame',
          color: AppPalette.rarityLegendary,
        );
      case 6:
        return const _AvatarPresentation(
          rarity: 'Legendary',
          subtitle: 'Shadow-tier premium collectible',
          color: AppPalette.rarityLegendary,
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
          rarity: 'Legendary',
          subtitle: 'Cosmic shadow collector',
          color: AppPalette.rarityLegendary,
        );
      case 10:
        return const _AvatarPresentation(
          rarity: 'Animated',
          subtitle: 'Reactive premium arena frame',
          color: AppPalette.rarityAnimated,
        );
      default:
        return const _AvatarPresentation(
          rarity: 'Legendary',
          subtitle: 'Premium collectible frame',
          color: AppPalette.rarityLegendary,
        );
    }
  }
}
