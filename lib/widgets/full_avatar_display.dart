import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/game_avatar.dart';
import '../services/avatar_analyzer_service.dart';
import '../services/local_store.dart';

/// Shared profile-avatar renderer used by Home, Settings, Arena, lobby, and
/// online gameplay.
///
/// The frame is entirely data-driven: when [equippedAvatarFrameAsset] resolves
/// to a real catalog asset, the profile photo is composited beneath that exact
/// frame. With no frame, the normal profile photo / initials presentation is
/// used. The outer stack never clips, so animated and oversized premium frames
/// remain visible at every responsive size.
class ArenaProfileAvatar extends StatelessWidget {
  final String? profileImageUrl;
  final String? localProfileImageAsset;
  final String? localProfileImagePath;
  final String? equippedAvatarFrameAsset;
  final GameAvatar? equippedAvatar;
  final double size;
  final bool showOnlineStatus;
  final Color statusColor;
  final String fallbackInitials;
  final BoxBorder? optionalBorder;
  final List<BoxShadow>? optionalGlow;
  final bool _useCurrentProfile;

  const ArenaProfileAvatar({
    super.key,
    this.profileImageUrl,
    this.localProfileImageAsset,
    this.localProfileImagePath,
    this.equippedAvatarFrameAsset,
    this.equippedAvatar,
    required this.size,
    this.showOnlineStatus = false,
    this.statusColor = const Color(0xFF31E981),
    this.fallbackInitials = 'P',
    this.optionalBorder,
    this.optionalGlow,
  }) : _useCurrentProfile = false;

  /// Binds to the current player's live photo and equipped-frame notifiers.
  const ArenaProfileAvatar.current({
    super.key,
    required this.size,
    this.showOnlineStatus = false,
    this.statusColor = const Color(0xFF31E981),
    this.fallbackInitials = 'P',
    this.optionalBorder,
    this.optionalGlow,
  })  : profileImageUrl = null,
        localProfileImageAsset = null,
        localProfileImagePath = null,
        equippedAvatarFrameAsset = null,
        equippedAvatar = null,
        _useCurrentProfile = true;

  @override
  Widget build(BuildContext context) {
    if (!_useCurrentProfile) {
      return _buildResolved(
        profileImageUrl: profileImageUrl,
        localProfileImageAsset: localProfileImageAsset,
        localProfileImagePath: localProfileImagePath,
        frameAsset: equippedAvatarFrameAsset,
        avatar: equippedAvatar,
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: LocalStore.equippedAvatarNotifier,
      builder: (_, avatarId, __) {
        final avatar = gameAvatarByIdOrNull(avatarId);
        return ValueListenableBuilder<String?>(
          valueListenable: LocalStore.offlineAvatarAssetNotifier,
          builder: (_, offlineAsset, __) => ValueListenableBuilder<String?>(
            valueListenable: LocalStore.profileImagePathNotifier,
            builder: (_, photoPath, __) => ValueListenableBuilder<String?>(
              valueListenable: LocalStore.profilePhotoUrlNotifier,
              builder: (_, photoUrl, __) => _buildResolved(
                profileImageUrl: photoUrl,
                localProfileImageAsset: offlineAsset,
                localProfileImagePath: photoPath,
                frameAsset: avatar?.assetPath,
                avatar: avatar,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResolved({
    required String? profileImageUrl,
    required String? localProfileImageAsset,
    required String? localProfileImagePath,
    required String? frameAsset,
    required GameAvatar? avatar,
  }) {
    final normalizedFrame = frameAsset?.trim();
    final hasFrame = normalizedFrame != null && normalizedFrame.isNotEmpty;
    final avatarContent = hasFrame
        ? CompositeAvatar(
            assetPath: normalizedFrame,
            offlineAssetPath: localProfileImageAsset,
            photoUrl: profileImageUrl,
            photoPath: localProfileImagePath,
            size: size,
            fallbackName: fallbackInitials,
            showFrame: true,
            profileSizeRatio: avatar?.previewScale ?? 0.80,
            frameScale: avatar?.frameScale ?? 1.0,
            verticalOffset: avatar?.verticalOffset ?? 0.0,
            innerCircleScale: avatar?.innerCircleScale ?? 1.0,
          )
        : CleanAvatar(
            size: size,
            offlineAssetPath: localProfileImageAsset,
            photoUrl: profileImageUrl,
            photoPath: localProfileImagePath,
            fallbackName: fallbackInitials,
          );

    final indicatorSize = (size * 0.24).clamp(10.0, 18.0);
    // Both framed and frameless avatars are circular now, so any optional
    // glow/border ring uses a full-circle radius.
    final borderRadius = BorderRadius.circular(size / 2);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (optionalGlow != null && optionalGlow!.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    boxShadow: optionalGlow,
                  ),
                ),
              ),
            ),
          avatarContent,
          if (optionalBorder != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: optionalBorder,
                  ),
                ),
              ),
            ),
          if (showOnlineStatus)
            Positioned(
              right: -indicatorSize * 0.04,
              bottom: -indicatorSize * 0.04,
              child: Container(
                width: indicatorSize,
                height: indicatorSize,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF07101F),
                    width: (indicatorSize * 0.15).clamp(1.5, 2.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.58),
                      blurRadius: indicatorSize * 0.55,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Self-contained avatar widget that listens to the global photo URL notifier.
///
/// Usage: FullAvatarDisplay(size: 48, avatar: myAvatar)
/// - automatically reads the profile photo from the bound notifier.
///
/// For call sites that need to pass photoUrl manually (e.g. opponent avatars),
/// use [CompositeAvatar] directly.
class FullAvatarDisplay extends StatelessWidget {
  final double size;

  /// Equipped paid-avatar frame. Only rendered when [showFrame] is true (the
  /// store gallery / coin-shop showcase). For profile displays it is ignored —
  /// profiles show a clean rounded-square photo, never a decorative frame.
  final GameAvatar? avatar;
  final String fallbackName;

  /// When true, render the decorative avatar frame composite (store / showcase
  /// surfaces where the frame IS the product). When false (default, and every
  /// profile surface — Home, Settings, Rooms, Lobby, Online) render a clean,
  /// frameless rounded-square of the real portrait / Google photo / initials.
  final bool showFrame;

  const FullAvatarDisplay({
    super.key,
    required this.size,
    required this.avatar,
    this.fallbackName = 'P',
    this.showFrame = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _OfflineAvatarAssetNotifier.instance,
      builder: (_, offlineAsset, __) => ValueListenableBuilder<String?>(
        valueListenable: _ProfilePhotoPathNotifier.instance,
        builder: (_, photoPath, __) => ValueListenableBuilder<String?>(
          valueListenable: _ProfilePhotoNotifier.instance,
          builder: (_, photoUrl, __) {
            return ArenaProfileAvatar(
              profileImageUrl: photoUrl,
              localProfileImageAsset: offlineAsset,
              localProfileImagePath: photoPath,
              equippedAvatarFrameAsset: showFrame ? avatar?.assetPath : null,
              equippedAvatar: showFrame ? avatar : null,
              size: size,
              fallbackInitials: fallbackName,
            );
          },
        ),
      ),
    );
  }

  /// Call once at app startup:
  ///   FullAvatarDisplay.bindNotifier(LocalStore.profilePhotoUrlNotifier);
  static void bindNotifier(ValueNotifier<String?> notifier) {
    _ProfilePhotoNotifier._bound = notifier;
  }

  static void bindLocalPathNotifier(ValueNotifier<String?> notifier) {
    _ProfilePhotoPathNotifier._bound = notifier;
  }

  static void bindOfflineAvatarAssetNotifier(ValueNotifier<String?> notifier) {
    _OfflineAvatarAssetNotifier._bound = notifier;
  }
}

/// Thin indirection so full_avatar_display.dart doesn't import main.dart.
class _ProfilePhotoNotifier {
  static ValueNotifier<String?>? _bound;
  static ValueNotifier<String?> get instance =>
      _bound ?? ValueNotifier<String?>(null);
}

class _ProfilePhotoPathNotifier {
  static ValueNotifier<String?>? _bound;
  static ValueNotifier<String?> get instance =>
      _bound ?? ValueNotifier<String?>(null);
}

/// Notifier for the offline character portrait asset path (man.webp / feminine.webp).
/// Non-null while in offline mode; null when online.
class _OfflineAvatarAssetNotifier {
  static ValueNotifier<String?>? _bound;
  static ValueNotifier<String?> get instance =>
      _bound ?? ValueNotifier<String?>(null);
}

/// Low-level compositing widget - single source of truth for avatar rendering.
///
/// Stack architecture (bottom -> top):
///   1. Profile picture - Gmail URL or initials fallback, clipped to circle,
///      sized at `size * profileSizeRatio` (default 80%).
///   2. Avatar frame asset - rendered with [BoxFit.contain] (never cropped),
///      shifted by [verticalOffset] via Transform.translate.
class CompositeAvatar extends StatefulWidget {
  final String? assetPath;
  final String? offlineAssetPath;
  final String? photoUrl;
  final String? photoPath;
  final double size;
  final String fallbackName;
  final double profileSizeRatio;
  final double frameScale;
  final double verticalOffset;
  final double innerCircleScale;

  /// When false (default), the decorative frame is NOT drawn — the widget
  /// renders a clean rounded-square photo. Set true only on store / showcase
  /// surfaces that intentionally preview the paid frame.
  final bool showFrame;

  const CompositeAvatar({
    super.key,
    this.assetPath,
    this.offlineAssetPath,
    this.photoUrl,
    this.photoPath,
    required this.size,
    this.fallbackName = 'P',
    this.showFrame = false,
    this.profileSizeRatio = 0.80,
    this.frameScale = 1.0,
    this.verticalOffset = 0.0,
    this.innerCircleScale = 1.0,
  });

  @override
  State<CompositeAvatar> createState() => _CompositeAvatarState();
}

class _CompositeAvatarState extends State<CompositeAvatar> {
  late Future<AvatarDimension> _dimensionFuture;

  @override
  void initState() {
    super.initState();
    _loadDimension();
  }

  @override
  void didUpdateWidget(CompositeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.assetPath != oldWidget.assetPath ||
        widget.showFrame != oldWidget.showFrame) {
      _loadDimension();
    }
  }

  void _loadDimension() {
    if (!widget.showFrame ||
        widget.assetPath == null ||
        widget.assetPath!.isEmpty) {
      // Create a dummy future for No-Frame scenarios
      _dimensionFuture = Future.value(AvatarDimension(
        centerDxRatio: 0.5,
        centerDyRatio: 0.5,
        radiusRatio: widget.profileSizeRatio / 2,
      ));
    } else {
      _dimensionFuture = AvatarAnalyzerService.analyze(
        widget.assetPath!,
        defaultProfileSizeRatio: widget.profileSizeRatio,
        defaultVerticalOffsetRatio: widget.verticalOffset,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Frameless (default): render the clean rounded-square photo. Used by every
    // opponent / profile call site that constructs CompositeAvatar directly.
    if (!widget.showFrame) {
      return CleanAvatar(
        size: widget.size,
        offlineAssetPath: widget.offlineAssetPath,
        photoUrl: widget.photoUrl,
        photoPath: widget.photoPath,
        fallbackName: widget.fallbackName,
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<AvatarDimension>(
        future: _dimensionFuture,
        builder: (context, snapshot) {
          // Use cached dimension if available, otherwise safe defaults
          final dim = snapshot.data ??
              AvatarDimension(
                centerDxRatio: 0.5,
                centerDyRatio: 0.5,
                radiusRatio: widget.profileSizeRatio / 2,
              );

          return _AvatarContent(
            size: widget.size,
            dim: dim,
            assetPath: widget.assetPath,
            offlineAssetPath: widget.offlineAssetPath,
            photoUrl: widget.photoUrl,
            photoPath: widget.photoPath,
            fallbackName: widget.fallbackName,
            frameScale: widget.frameScale,
            innerCircleScale: widget.innerCircleScale,
            verticalOffset: widget.verticalOffset,
          );
        },
      ),
    );
  }
}

/// Helper widget to render avatar content without blocking on FutureBuilder.
class _AvatarContent extends StatelessWidget {
  final double size;
  final AvatarDimension dim;
  final String? assetPath;
  final String? offlineAssetPath;
  final String? photoUrl;
  final String? photoPath;
  final String fallbackName;
  final double frameScale;
  final double innerCircleScale;
  final double verticalOffset;

  const _AvatarContent({
    required this.size,
    required this.dim,
    this.assetPath,
    this.offlineAssetPath,
    this.photoUrl,
    this.photoPath,
    required this.fallbackName,
    required this.frameScale,
    required this.innerCircleScale,
    required this.verticalOffset,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Layer 1: circular profile picture
              _buildProfileLayer(),

              // Layer 2: avatar frame asset
              if (assetPath != null && assetPath!.isNotEmpty)
                Positioned.fill(
                  child: Transform.scale(
                    scale: frameScale,
                    child: Image.asset(
                      assetPath!,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileLayer() {
    // The frame is painted on top, so a photo slightly larger than the detected
    // hole is masked to the opening (no gap). Allow a wide range: small-opening
    // frames (e.g. hooded) can go down to 0.26, open-ring frames up to 0.50.
    final scaledRadiusRatio =
        (dim.radiusRatio * innerCircleScale).clamp(0.26, 0.50);
    final circleSize = size * scaledRadiusRatio * 2;
    final maxLeft = size - circleSize;
    final rawDx = (size * dim.centerDxRatio) - (circleSize / 2);
    final rawDy =
        (size * (dim.centerDyRatio - verticalOffset)) - (circleSize / 2);
    final dx = rawDx.clamp(0.0, maxLeft);
    final dy = rawDy.clamp(0.0, maxLeft);

    final whiteCircle = Container(
      width: circleSize,
      height: circleSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFFFFF),
      ),
    );

    // Priority 0: offline character portrait asset — overrides everything.
    if (offlineAssetPath != null && offlineAssetPath!.isNotEmpty) {
      return Positioned(
        left: dx,
        top: dy,
        child: SizedBox(
          width: circleSize,
          height: circleSize,
          child: Stack(
            children: [
              whiteCircle,
              ClipOval(
                child: Image.asset(
                  offlineAssetPath!,
                  width: circleSize,
                  height: circleSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _InitialCircle(name: fallbackName, size: circleSize),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (photoPath != null && photoPath!.isNotEmpty) {
      final file = File(photoPath!);
      return Positioned(
        left: dx,
        top: dy,
        child: SizedBox(
          width: circleSize,
          height: circleSize,
          child: Stack(
            children: [
              whiteCircle,
              ClipOval(
                child: Image(
                  image: FileImage(file),
                  width: circleSize,
                  height: circleSize,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.06),
                  errorBuilder: (_, __, ___) =>
                      _InitialCircle(name: fallbackName, size: circleSize),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return Positioned(
        left: dx,
        top: dy,
        child: SizedBox(
          width: circleSize,
          height: circleSize,
          child: Stack(
            children: [
              whiteCircle,
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photoUrl!,
                  width: circleSize,
                  height: circleSize,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.06),
                  placeholder: (_, __) => _InitialCircle(
                    name: fallbackName,
                    size: circleSize,
                  ),
                  errorWidget: (_, __, ___) => _InitialCircle(
                    name: fallbackName,
                    size: circleSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      left: dx,
      top: dy,
      child: Stack(
        children: [
          whiteCircle,
          _InitialCircle(name: fallbackName, size: circleSize),
        ],
      ),
    );
  }
}

/// Clean, frameless circular avatar. Single source of truth for every profile
/// display across the app (Home, Settings, Rooms, Lobby, Online) when no frame
/// is equipped.
///
/// Priority: real portrait (offline character) → local photo file → Google
/// photo URL → initials. No decorative frame, gradient box or glow is drawn —
/// just the photo in a clean circle with a hairline ring for definition on the
/// dark background, so it matches the circular shape of the framed avatars.
class CleanAvatar extends StatelessWidget {
  final double size;
  final String? offlineAssetPath;
  final String? photoUrl;
  final String? photoPath;
  final String fallbackName;

  const CleanAvatar({
    super.key,
    required this.size,
    this.offlineAssetPath,
    this.photoUrl,
    this.photoPath,
    this.fallbackName = 'P',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: size >= 64 ? 1.4 : 1.0,
        ),
      ),
      child: ClipOval(
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    // Priority 1: real portrait (offline character / selected real avatar).
    if (offlineAssetPath != null && offlineAssetPath!.isNotEmpty) {
      return Image.asset(
        offlineAssetPath!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            _InitialSquare(name: fallbackName, size: size),
      );
    }
    // Priority 2: local photo file (legacy custom photo).
    if (photoPath != null && photoPath!.isNotEmpty) {
      return Image(
        image: FileImage(File(photoPath!)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            _InitialSquare(name: fallbackName, size: size),
      );
    }
    // Priority 3: Google profile photo.
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _InitialSquare(name: fallbackName, size: size),
        errorWidget: (_, __, ___) =>
            _InitialSquare(name: fallbackName, size: size),
      );
    }
    // Priority 4: initials.
    return _InitialSquare(name: fallbackName, size: size);
  }
}

/// Rounded-square initial fallback — matches [CleanAvatar]'s shape so the
/// no-image state looks intentional rather than broken.
class _InitialSquare extends StatelessWidget {
  final String name;
  final double size;
  const _InitialSquare({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? 'P' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15233B), Color(0xFF0C1526)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: size * 0.40,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF58D8FF),
        ),
      ),
    );
  }
}

/// White circle with first initial - placeholder / fallback.
class _InitialCircle extends StatelessWidget {
  final String name;
  final double size;
  const _InitialCircle({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? 'P' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFFFFF),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Color(0xFF58D8FF),
        ),
      ),
    );
  }
}
