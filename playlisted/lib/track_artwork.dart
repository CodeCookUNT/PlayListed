import 'package:flutter/material.dart';

class TrackArtwork extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final BoxFit fit;

  const TrackArtwork({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.icon = Icons.music_note,
    this.backgroundColor,
    this.iconColor,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade300,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: iconColor ?? Colors.white70),
    );

    final normalizedUrl = imageUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        normalizedUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
