import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

/// A tappable row of 5 stars. [value] is 0..5 (0 = nothing selected yet).
class StarRatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        final filled = starIndex <= value;
        return GestureDetector(
          onTap: () {
            HapticService.selection();
            onChanged(starIndex);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
              size: size,
            ),
          ),
        );
      }),
    );
  }
}
