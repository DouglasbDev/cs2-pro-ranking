import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows a bundled asset image (player photo / team logo) referenced by a
/// nullable asset-relative path from the DB. Falls back to a placeholder
/// icon when the path is null/empty or the asset doesn't exist.
///
/// Team logos (`shape: BoxShape.rectangle`) get a light card behind them:
/// crests scraped from prosettings.net are commonly monochrome (often pure
/// black) art on a transparent background, built for light UIs — without a
/// light backing they disappear against this app's dark theme. Player
/// photos are full-frame photographs with no transparency, so they don't
/// need it and stay circular with no backing card.
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

  bool get _isLogo => shape == BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    return _isLogo ? _buildLogo() : _buildAvatar();
  }

  Widget _buildLogo() {
    final path = assetPath;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: AppColors.logoBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: (path == null || path.isEmpty)
          ? _fallbackIcon()
          : Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
            ),
    );
  }

  Widget _buildAvatar() {
    final path = assetPath;
    if (path == null || path.isEmpty) {
      return _avatarFallback();
    }
    // Jerseys are frequently dark (often black) and would blend straight
    // into the app's near-black background with no visible edge — a thin
    // light ring gives the circle a defined boundary regardless of what
    // color the photo happens to be.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipOval(
        child: Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _avatarFallback(),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      alignment: Alignment.center,
      child: _fallbackIcon(),
    );
  }

  Widget _fallbackIcon() {
    return Icon(fallbackIcon, size: size * 0.5, color: AppColors.textSecondary);
  }
}
