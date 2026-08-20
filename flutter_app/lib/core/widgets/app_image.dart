import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

const double _logoPaddingFactor = 0.14;
const double _logoCornerRadius = 12.0;
const double _avatarRingWidth = 1.5;
const double _fallbackIconSizeFactor = 0.5;

/// Shows a bundled asset image (player photo / team logo) referenced by a
/// nullable asset-relative path from the DB. Falls back to a placeholder
/// icon when the path is null/empty or the asset doesn't exist.
///
/// Team logos (`shape: BoxShape.rectangle`) get a light card behind them:
/// crests scraped from prosettings.net are commonly monochrome (often pure
/// black) art on a transparent background, built for light UIs — without a
/// light backing they disappear against this app's dark theme. Player
/// photos are full-frame photographs with no transparency, so they don't
/// need it and stay circular with a thin ring instead, for contrast
/// against dark jerseys.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.assetPath,
    required this.size,
    this.shape = BoxShape.circle,
    this.fallbackIcon = Icons.person,
  });

  final String? assetPath;
  final double size;
  final BoxShape shape;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return switch (shape) {
      BoxShape.rectangle => _LogoImage(
          assetPath: assetPath, size: size, fallbackIcon: fallbackIcon),
      BoxShape.circle => _AvatarImage(
          assetPath: assetPath, size: size, fallbackIcon: fallbackIcon),
    };
  }
}

class _LogoImage extends StatelessWidget {
  const _LogoImage(
      {required this.assetPath,
      required this.size,
      required this.fallbackIcon});

  final String? assetPath;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * _logoPaddingFactor),
      decoration: BoxDecoration(
        color: AppColors.logoBackground,
        borderRadius: BorderRadius.circular(_logoCornerRadius),
      ),
      alignment: Alignment.center,
      child: switch (path) {
        null || '' => _FallbackIcon(icon: fallbackIcon, size: size),
        _ => Image.asset(
            path,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _FallbackIcon(icon: fallbackIcon, size: size),
          ),
      },
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage(
      {required this.assetPath,
      required this.size,
      required this.fallbackIcon});

  final String? assetPath;
  final double size;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null || path.isEmpty) {
      return _AvatarFallback(icon: fallbackIcon, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: _avatarRingWidth),
      ),
      child: ClipOval(
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _AvatarFallback(icon: fallbackIcon, size: size),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: _avatarRingWidth),
      ),
      alignment: Alignment.center,
      child: _FallbackIcon(icon: icon, size: size),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon,
        size: size * _fallbackIconSizeFactor, color: AppColors.textSecondary);
  }
}
