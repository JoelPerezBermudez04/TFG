import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String? imatgeUrl;
  final String? emoji;
  final double size;
  final Color backgroundColor;
  final double borderRadius;

  const ProductImage({
    super.key,
    this.imatgeUrl,
    this.emoji,
    required this.size,
    required this.backgroundColor,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (imatgeUrl != null && imatgeUrl!.isNotEmpty) {
      return Image.network(
        imatgeUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildEmoji();
        },
        errorBuilder: (context, error, stackTrace) => _buildEmoji(),
      );
    }
    return _buildEmoji();
  }

  Widget _buildEmoji() {
    return Center(
      child: Text(
        emoji ?? '🛒',
        style: TextStyle(fontSize: size * 0.45),
      ),
    );
  }
}