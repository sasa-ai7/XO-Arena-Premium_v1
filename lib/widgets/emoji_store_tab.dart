import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../core/coin_format.dart';
import '../core/app_theme.dart';
import '../models/game_emoji.dart';
import 'app_ui.dart';

/// Emoji gallery / store tab.
///
/// Top: five neon equipped slots the player customizes for gameplay reactions.
/// Below: the full catalog with Buy / Equip / Equipped states, mirroring
/// [AvatarStoreTab]. All coin spending flows through the shared wallet in
/// `LocalStore` — there is no separate emoji currency.
class EmojiStoreTab extends StatelessWidget {
  final List<String> ownedEmojis;
  final List<String> equippedEmojis;
  final bool busy;
  final int coins;
  final Future<void> Function(GameEmoji emoji) onBuyEmoji;
  final Future<void> Function(String id) onEquipEmoji;
  final Future<void> Function(String id) onUnequipEmoji;
  final Future<void> Function(int slot, String id) onEquipToSlot;

  const EmojiStoreTab({
    super.key,
    required this.ownedEmojis,
    required this.equippedEmojis,
    required this.busy,
    required this.coins,
    required this.onBuyEmoji,
    required this.onEquipEmoji,
    required this.onUnequipEmoji,
    required this.onEquipToSlot,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ownedSet = ownedEmojis.toSet();
    final equippedSet = equippedEmojis.toSet();

    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.74,
    );

    return CustomScrollView(
      slivers: [
        // ── Equipped slots panel ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: _EquippedSlotsPanel(
              equippedEmojis: equippedEmojis,
              busy: busy,
              onTapSlot: (slot) => _handleSlotTap(context, slot),
              onRemoveSlot: (id) => onUnequipEmoji(id),
            ),
          ),
        ),

        // ── Gallery header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            child: Text(
              l10n.emojiGalleryHeader,
              style: safeOrbitron(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                color: AppPalette.textSubtle,
              ),
            ),
          ),
        ),

        // ── Catalog grid ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid(
            gridDelegate: gridDelegate,
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final emoji = EmojiCatalog.all[index];
                final owned = emoji.isFree || ownedSet.contains(emoji.id);
                final equipped = equippedSet.contains(emoji.id);
                return _EmojiCard(
                  emoji: emoji,
                  owned: owned,
                  equipped: equipped,
                  busy: busy,
                  onBuy: onBuyEmoji,
                  onEquip: onEquipEmoji,
                  onUnequip: onUnequipEmoji,
                );
              },
              childCount: EmojiCatalog.all.length,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSlotTap(BuildContext context, int slot) async {
    if (busy) return;
    // Owned emojis that are not already in another slot (allow the one in this
    // slot so the sheet can also act as "replace").
    final equipped = List<String>.from(equippedEmojis);
    final currentInSlot = slot < equipped.length ? equipped[slot] : null;
    final selectable = ownedEmojis
        .where((id) => !equipped.contains(id) || id == currentInSlot)
        .toList();

    final picked = await _showEmojiPickerSheet(
      context,
      options: selectable,
      currentId: currentInSlot,
    );
    if (picked == null) return;
    if (picked == currentInSlot) return;
    await onEquipToSlot(slot, picked);
  }
}

/// Bottom-sheet picker of owned emojis for a slot.
Future<String?> _showEmojiPickerSheet(
  BuildContext context, {
  required List<String> options,
  String? currentId,
}) {
  final l10n = AppL10n.of(context);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.panelElevated.withOpacity(0.98),
                AppPalette.panelDeep.withOpacity(0.98),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppPalette.primary.withOpacity(0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.emojiPickTitle,
                style: safeOrbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    l10n.emojiNoneToEquip,
                    style: bodyFont(context).copyWith(
                      fontSize: 13,
                      color: AppPalette.textMuted,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final id = options[index];
                      final selected = id == currentId;
                      return GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(id),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.04),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF3DCC6E).withOpacity(0.80)
                                  : AppPalette.primary.withOpacity(0.28),
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: _EmojiImage(id: id),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The 5 equipped slots row with a neon frame.
class _EquippedSlotsPanel extends StatelessWidget {
  final List<String> equippedEmojis;
  final bool busy;
  final ValueChanged<int> onTapSlot;
  final ValueChanged<String> onRemoveSlot;

  const _EquippedSlotsPanel({
    required this.equippedEmojis,
    required this.busy,
    required this.onTapSlot,
    required this.onRemoveSlot,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      borderColor: AppPalette.primary.withOpacity(0.34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_emotions_rounded,
                  size: 16, color: AppPalette.primary),
              const SizedBox(width: 8),
              Text(
                l10n.emojiEquippedTitle,
                style: safeOrbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.emojiEquippedHint,
            style: bodyFont(context).copyWith(
              fontSize: 11,
              color: AppPalette.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(EmojiCatalog.maxEquipped, (i) {
              final id = i < equippedEmojis.length ? equippedEmojis[i] : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: i == EmojiCatalog.maxEquipped - 1 ? 0 : 8),
                  child: _EquippedSlot(
                    id: id,
                    busy: busy,
                    onTap: () => onTapSlot(i),
                    onRemove: id == null ? null : () => onRemoveSlot(id),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EquippedSlot extends StatelessWidget {
  final String? id;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _EquippedSlot({
    required this.id,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final filled = id != null;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: busy ? null : onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: filled
                      ? [
                          AppPalette.primary.withOpacity(0.16),
                          Colors.black.withOpacity(0.20),
                        ]
                      : [
                          Colors.white.withOpacity(0.03),
                          Colors.white.withOpacity(0.01),
                        ],
                ),
                border: Border.all(
                  color: filled
                      ? AppPalette.primary.withOpacity(0.60)
                      : AppPalette.strokeSoft,
                  width: filled ? 1.4 : 1,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: AppPalette.primary.withOpacity(0.22),
                          blurRadius: 14,
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(7),
              child: filled
                  ? _EmojiImage(id: id!)
                  : Icon(Icons.add_rounded,
                      color: AppPalette.textMuted.withOpacity(0.8), size: 22),
            ),
          ),
          if (filled && onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: busy ? null : onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.danger,
                    border: Border.all(color: Colors.white.withOpacity(0.85)),
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiCard extends StatelessWidget {
  final GameEmoji emoji;
  final bool owned;
  final bool equipped;
  final bool busy;
  final Future<void> Function(GameEmoji) onBuy;
  final Future<void> Function(String id) onEquip;
  final Future<void> Function(String id) onUnequip;

  const _EmojiCard({
    required this.emoji,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = equipped
        ? const Color(0xFF3DCC6E).withOpacity(0.88)
        : owned
            ? AppPalette.primary.withOpacity(0.40)
            : AppPalette.gold.withOpacity(0.34);
    final bgColor = equipped
        ? Color.lerp(AppPalette.panelElevated, const Color(0xFF3DCC6E), 0.22)
        : AppPalette.panel;

    return AppGlassCard(
      padding: const EdgeInsets.all(9),
      borderColor: borderColor,
      backgroundColor: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (emoji.isFree)
            Align(
              alignment: Alignment.centerLeft,
              child: _Tag(
                label: AppL10n.of(context).emojiFreeTag,
                color: AppPalette.primary,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _EmojiImage(id: emoji.id),
            ),
          ),
          SizedBox(
            height: 34,
            child: _EmojiActionButton(
              emoji: emoji,
              owned: owned,
              equipped: equipped,
              busy: busy,
              onBuy: onBuy,
              onEquip: onEquip,
              onUnequip: onUnequip,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiActionButton extends StatelessWidget {
  final GameEmoji emoji;
  final bool owned;
  final bool equipped;
  final bool busy;
  final Future<void> Function(GameEmoji) onBuy;
  final Future<void> Function(String id) onEquip;
  final Future<void> Function(String id) onUnequip;

  const _EmojiActionButton({
    required this.emoji,
    required this.owned,
    required this.equipped,
    required this.busy,
    required this.onBuy,
    required this.onEquip,
    required this.onUnequip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (equipped) {
      return AppPillButton(
        label: l10n.storeEquipped,
        fill: const Color(0xFF3DCC6E),
        stroke: const Color(0xFF3DCC6E).withOpacity(0.55),
        onPressed: busy ? null : () => onUnequip(emoji.id),
        icon: Icons.check_rounded,
        labelFontSize: 10,
        labelLetterSpacing: 0.6,
      );
    }

    if (owned) {
      return AppPillButton(
        label: l10n.storeEquip,
        fill: Colors.white.withOpacity(0.04),
        stroke: AppPalette.primary.withOpacity(0.42),
        onPressed: busy ? null : () => onEquip(emoji.id),
        icon: Icons.bolt_rounded,
        iconColor: AppPalette.primary,
        labelFontSize: 10,
        labelLetterSpacing: 0.6,
      );
    }

    return AppPillButton(
      label: l10n.buyWithPrice(formatCoins(emoji.priceCoins)),
      fill: AppPalette.success,
      stroke: AppPalette.success.withOpacity(0.55),
      onPressed: busy ? null : () => onBuy(emoji),
      leading: Image.asset(
        'assets/coin/COIN.webp',
        height: 12,
        fit: BoxFit.contain,
      ),
      leadingSlotWidth: 14,
      fitLabel: true,
      labelFontSize: 10,
      labelLetterSpacing: 0.4,
    );
  }
}

/// Renders an emoji asset by catalog id, with a graceful fallback.
class _EmojiImage extends StatelessWidget {
  final String id;
  const _EmojiImage({required this.id});

  @override
  Widget build(BuildContext context) {
    final path = EmojiCatalog.assetPathOf(id);
    if (path == null) {
      return Icon(Icons.emoji_emotions_outlined,
          color: AppPalette.textMuted, size: 28);
    }
    return Image.asset(
      path,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_rounded,
        color: AppPalette.textMuted.withOpacity(0.6),
        size: 24,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Text(
        label.toUpperCase(),
        style: safeOrbitron(
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }
}
