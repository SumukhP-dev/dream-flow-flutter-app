import 'package:flutter/material.dart';

class ParentalControlBadge extends StatelessWidget {
  final String? ageRating;
  final bool isApproved;
  final bool showApproved;

  const ParentalControlBadge({
    super.key,
    this.ageRating,
    this.isApproved = false,
    this.showApproved = false,
  });

  Color _getAgeRatingColor(String rating) {
    switch (rating.toUpperCase()) {
      case 'G':
        return Colors.green;
      case 'PG':
        return Colors.blue;
      case 'PG-13':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ageRating != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getAgeRatingColor(ageRating!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ageRating!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (showApproved && isApproved) const SizedBox(width: 8),
        ],
        if (showApproved && isApproved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green,
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  color: Colors.green,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  'Parent Approved',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

