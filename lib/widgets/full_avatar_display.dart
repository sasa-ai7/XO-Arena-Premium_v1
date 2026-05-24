import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/game_avatar.dart';
import '../services/avatar_analyzer_service.dart';

/// Self-contained avatar widget that listens to the global photo URL notifier.
///
/// Usage: FullAvatarDisplay(size: 48, avatar: myAvatar)
/// - automatically reads the profile photo from the bound notifier.
///
/// For call sites that need to pass photoUrl manually (e.g. opponent avatars),
/// use [CompositeAvatar] directly.
class FullAvatarDisplay extends StatelessWidget {
  final double size;

  /// Equipped paid-avatar frame. **Pass null** when the user has no avatar
  /// equipped (e.g. new accounts, unequipped state) — Avatar__1 must NOT
  /// be used as a fallback because it is a paid store item.
  final GameAvatar? avatar;
  final String fallbackName;

  const FullAvatarDisplay({
    super.key,
    required this.size,
    required this.avatar,
    this.fallbackName = 'P',
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _OfflineAvatarAssetNotifier.instance,
      builder: (_, offlineAsset, __) => ValueListenableBuilder<String?>(
        valueListenable: _ProfilePhotoPathNotifier.instance,
        builder: (_, photoPath, __) => ValueListenableBuilder<String?>(
          valueListenable: _ProfilePhotoNotifier.instance,
          builder: (_, photoUrl, __) => CompositeAvatar(
            assetPath: avatar?.assetPath,
            offlineAssetPath: offlineAsset,
            photoUrl: photoUrl,
            photoPath: photoPath,
            size: size,
            fallbackName: fallbackName,
            profileSizeRatio: avatar?.previewScale ?? 0.80,
            frameScale: avatar?.frameScale ?? 1.0,
            verticalOffset: avatar?.verticalOffset ?? 0.0,
            innerCircleScale: avatar?.innerCircleScale ?? 1.0,
          ),
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

/// Notifier for the offline character portrait asset path (man.png / feminine.png).
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

  const CompositeAvatar({
    super.key,
    this.assetPath,
    this.offlineAssetPath,
    this.photoUrl,
    this.photoPath,
    required this.size,
    this.fallbackName = 'P',
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
    if (widget.assetPath != oldWidget.assetPath) {
      _loadDimension();
    }
  }

  void _loadDimension() {
    if (widget.assetPath == null || widget.assetPath!.isEmpty) {
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<AvatarDimension>(
        future: _dimensionFuture,
        builder: (context, snapshot) {
          // Use cached dimension if available, otherwise safe defaults
          final dim = snapshot.data ?? AvatarDimension(
            centerDxRatio: 0.5,
            centerDyRatio: 0.5 - widget.verticalOffset,
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
    final scaledRadiusRatio = (dim.radiusRatio * innerCircleScale).clamp(0.30, 0.47);
    final circleSize = size * scaledRadiusRatio * 2;
    final maxLeft = size - circleSize;
    final rawDx = (size * dim.centerDxRatio) - (circleSize / 2);
    final rawDy = (size * (dim.centerDyRatio - verticalOffset)) - (circleSize / 2);
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
