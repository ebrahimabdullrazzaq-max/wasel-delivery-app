// pages/star_rating.dart
import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int maxStars; // Default: 5
  final Color filledColor; // Default: Yellow
  final Color emptyColor; // Default: Gray
  final double size; // Default: 24

  const StarRating({
    Key? key,
    required this.rating,
    this.maxStars = 5,
    this.filledColor = Colors.amber,
    this.emptyColor = Colors.grey,
    this.size = 24,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filledCount = rating.floor(); // Number of fully filled stars
    final hasHalfStar = rating - filledCount >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Full stars
        for (int i = 0; i < filledCount; i++)
          Icon(
            Icons.star,
            color: filledColor,
            size: size,
          ),
        // Half star if needed
        if (hasHalfStar)
          Icon(
            Icons.star_half,
            color: filledColor,
            size: size,
          ),
        // Empty stars
        for (int i = filledCount + (hasHalfStar ? 1 : 0); i < maxStars; i++)
          Icon(
            Icons.star_border,
            color: emptyColor,
            size: size,
          ),
      ],
    );
  }
}