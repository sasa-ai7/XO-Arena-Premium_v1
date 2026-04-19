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
  final GameAvatar avatar;
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
      valueListenable: _ProfilePhotoNotifier.instance,
      builder: (_, photoUrl, __) => CompositeAvatar(
        assetPath: avatar.assetPath,
        photoUrl: photoUrl,
        size: size,
        fallbackName: fallbackName,
        profileSizeRatio: avatar.profileSizeRatio,
        verticalOffset: avatar.verticalOffset,
      ),
    );
  }

  /// Call once at app startup:
  ///   FullAvatarDisplay.bindNotifier(LocalStore.profilePhotoUrlNotifier);
  static void bindNotifier(ValueNotifier<String?> notifier) {
    _ProfilePhotoNotifier._bound = notifier;
  }
}

/// Thin indirection so full_avatar_display.dart doesn't import main.dart.
class _ProfilePhotoNotifier {
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
  final String? photoUrl;
  final double size;
  final String fallbackName;
  final double profileSizeRatio;
  final double verticalOffsetRatio;
  final double verticalOffset;

  const CompositeAvatar({
    super.key,
    this.assetPath,
    this.photoUrl,
    required this.size,
    this.fallbackName = 'P',
    this.profileSizeRatio = 0.80,
    this.verticalOffsetRatio = 0.04,
    this.verticalOffset = 0.0,
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
        defaultVerticalOffsetRatio: widget.verticalOffsetRatio,
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
          final dim = snapshot.data ?? AvatarDimension(
            centerDxRatio: 0.5,
            centerDyRatio: 0.5 - widget.verticalOffsetRatio,
            radiusRatio: widget.profileSizeRatio / 2,
          );

          return AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // -- Layer 1 (bottom): circular profile picture --
                _buildProfileLayer(dim),

                // -- Layer 2 (top): full uncropped avatar frame --
                if (widget.assetPath != null && widget.assetPath!.isNotEmpty)
                  Positioned.fill(
                    child: Image.asset(
                      widget.assetPath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileLayer(AvatarDimension dim) {
    final circleSize = widget.size * dim.radiusRatio * 2;
    
    // The image widget size is widget.size. 
    // Top-left of the circle should be centered at (dim.centerDxRatio, dim.centerDyRatio)
    final dx = (widget.size * dim.centerDxRatio) - (circleSize / 2);
    final dy = (widget.size * dim.centerDyRatio) - (circleSize / 2);

    final whiteCircle = Container(
      width: circleSize,
      height: circleSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFFFFF),
      ),
    );

    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
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
                  imageUrl: widget.photoUrl!,
                  width: circleSize,
                  height: circleSize,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _InitialCircle(
                    name: widget.fallbackName,
                    size: circleSize,
                  ),
                  errorWidget: (_, __, ___) => _InitialCircle(
                    name: widget.fallbackName,
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
          _InitialCircle(name: widget.fallbackName, size: circleSize),
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
