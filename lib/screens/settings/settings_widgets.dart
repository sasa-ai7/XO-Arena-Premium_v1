import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/full_avatar_display.dart';
import '../../models/game_avatar.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String email;
  final String provider;
  final int games;
  final int wins;
  final int losses;
  final int draws;
  final int topLevel;
  final GameAvatar? avatar;
  final bool editingName;
  final TextEditingController usernameController;
  /// When null, the camera-icon overlay is not rendered. Set to null since
  /// 2026-05 — profile photo now comes from Google Sign-In photoURL only.
  final VoidCallback? onCameraTap;
  final VoidCallback onEditName;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSaveName;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.email,
    required this.provider,
    required this.games,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.topLevel,
    required this.avatar,
    required this.editingName,
    required this.usernameController,
    this.onCameraTap,
    required this.onEditName,
    required this.onCancelEdit,
    required this.onSaveName,
  });

  @override
  Widget build(BuildContext context) {
    final avatarWidget = SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Hero(
            tag: 'profile_avatar',
            child: FullAvatarDisplay(
              size: 130,
              avatar: avatar,
              fallbackName: username,
            ),
          ),
          // Camera-icon overlay — only rendered if a tap handler was passed.
          // The handler is currently null app-wide (profile photo is taken
          // from Google Sign-In since 2026-05), so this branch never runs.
          if (onCameraTap != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppPalette.primary2, AppPalette.primary],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppPalette.gold.withValues(alpha: 0.40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.primary.withValues(alpha: 0.30),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  onPressed: onCameraTap,
                  icon: const Icon(Icons.camera_alt,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );

    return AppGlassCard(
      padding: const EdgeInsets.all(22),
      radius: 24,
      borderColor: AppPalette.strokeStrong.withValues(alpha: 0.72),
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
          color: Colors.black.withValues(alpha: 0.34),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
        BoxShadow(
          color: AppPalette.primary.withValues(alpha: 0.10),
          blurRadius: 30,
          spreadRadius: -8,
        ),
      ],
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              avatarWidget,
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'XO ARENA ID',
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: AppPalette.goldHighlight,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: editingName
                ? Row(
                    key: const ValueKey('edit-name'),
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usernameController,
                          maxLength: 20,
                          style: safeOrbitron(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor:
                                AppPalette.panelDeep.withValues(alpha: 0.90),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppPalette.strokeStrong
                                    .withValues(alpha: 0.60),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(14)),
                              borderSide: BorderSide(
                                color: AppPalette.goldHighlight
                                    .withValues(alpha: 0.92),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                          onPressed: onCancelEdit,
                          icon: const Icon(Icons.close, color: Colors.white70)),
                      IconButton(
                          onPressed: () => onSaveName(),
                          icon: const Icon(Icons.check,
                              color: AppPalette.primary)),
                    ],
                  )
                : Row(
                    key: const ValueKey('view-name'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: safeOrbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color:
                                    AppPalette.primary.withValues(alpha: 0.26),
                                blurRadius: 18,
                              ),
                              Shadow(
                                color: AppPalette.accentPurple
                                    .withValues(alpha: 0.18),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onEditName,
                        icon: const Icon(Icons.edit_rounded,
                            size: 16, color: AppPalette.primary),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 4),
          Text(email,
              style: safeInter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.textSubtle)),
          const SizedBox(height: 6),
          ProviderBadge(provider: provider),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.panelSoft.withValues(alpha: 0.96),
                  AppPalette.panelDeep.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.strokeSoft),
            ),
            child: Row(
              children: [
                Expanded(child: StatChip(value: games, label: 'GAMES')),
                const VerticalStatDivider(),
                Expanded(child: StatChip(value: wins, label: 'WINS')),
                const VerticalStatDivider(),
                Expanded(child: StatChip(value: losses, label: 'LOSSES')),
                const VerticalStatDivider(),
                Expanded(child: StatChip(value: draws, label: 'DRAWS')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppPalette.primary2.withValues(alpha: 0.94),
                  AppPalette.accentPurple.withValues(alpha: 0.86),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppPalette.gold.withValues(alpha: 0.34),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech,
                    color: AppPalette.goldHighlight, size: 20),
                const SizedBox(width: 8),
                Text(
                  'TOP LEVEL: ${topLevel} / 20',
                  style: safeOrbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderBadge extends StatelessWidget {
  final String provider;

  const ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == 'google';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isGoogle
            ? AppPalette.success.withValues(alpha: 0.14)
            : AppPalette.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isGoogle
              ? AppPalette.success.withValues(alpha: 0.34)
              : AppPalette.gold.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isGoogle ? Icons.verified : Icons.email_outlined,
              size: 13,
              color: isGoogle ? AppPalette.success : AppPalette.goldHighlight),
          const SizedBox(width: 6),
          Text(
            isGoogle ? 'GOOGLE VERIFIED' : 'EMAIL',
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isGoogle ? AppPalette.success : AppPalette.goldHighlight,
            ),
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  final int value;
  final String label;

  const StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString(),
          style: safeOrbitron(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppPalette.textSubtle),
        ),
      ],
    );
  }
}

class VerticalStatDivider extends StatelessWidget {
  const VerticalStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: AppPalette.strokeSoft,
    );
  }
}

class DangerZoneCard extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const DangerZoneCard(
      {required this.expanded, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x08FF3B30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x30FF3B30)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppPalette.danger),
                  const SizedBox(width: 10),
                  Text(
                    'DANGER ZONE',
                    style: safeOrbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppPalette.danger),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppPalette.danger),
                  ),
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: expanded ? 64 : 0,
            padding: EdgeInsets.fromLTRB(
                14, expanded ? 0 : 0, 14, expanded ? 12 : 0),
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: expanded
                    ? SizedBox(
                        width: double.infinity,
                        child: AppPillButton(
                          label: 'DELETE ACCOUNT',
                          fill: AppPalette.danger,
                          onPressed: onDelete,
                          icon: Icons.delete_forever,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumLogoutCard extends StatelessWidget {
  final VoidCallback onTap;

  const PremiumLogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.panelSoft.withValues(alpha: 0.98),
                AppPalette.panelDeep.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(
              color: AppPalette.gold.withValues(alpha: 0.34),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppPalette.gold.withValues(alpha: 0.10),
                blurRadius: 20,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.gold.withValues(alpha: 0.12),
                  border: Border.all(
                      color: AppPalette.gold.withValues(alpha: 0.32)),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppPalette.goldHighlight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SIGN OUT',
                    style: safeOrbitron(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white),
                  ),
                  Text(
                    'You will need to sign in again',
                    style: safeInter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.textSubtle),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class TinyBadge extends StatelessWidget {
  final String text;
  final Color color;

  const TinyBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: safeOrbitron(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color),
      ),
    );
  }
}

class Stat extends StatelessWidget {
  final String label;
  final int value;

  const Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Text(
            value.toString(),
            style: safeOrbitron(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: safeOrbitron(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingTile(
      {required this.icon,
      required this.label,
      this.subtitle,
      this.trailing,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.panelSoft.withValues(alpha: 0.95),
                AppPalette.panelDeep.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: AppPalette.strokeSoft),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.primary.withValues(alpha: 0.18),
                      AppPalette.accentPurple.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppPalette.strokeStrong, width: 0.7),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: safeOrbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: safeInter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppPalette.textSubtle),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppPalette.primary),
            ],
          ),
        ),
      ),
    );
  }
}
