import 'package:flutter/material.dart';

class RatingDisplay extends StatelessWidget {
  final double rating;
  final int totalReviews;
  final bool showTotalReviews;
  final double starSize;
  final Color starColor;
  final Color emptyStarColor;
  final TextStyle? textStyle;

  const RatingDisplay({
    super.key,
    required this.rating,
    this.totalReviews = 0,
    this.showTotalReviews = true,
    this.starSize = 16.0,
    this.starColor = Colors.amber,
    this.emptyStarColor = Colors.grey,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hiển thị sao
        Row(
          children: List.generate(5, (index) {
            final isFilled = index < rating.floor();
            final isHalfFilled = index == rating.floor() && rating % 1 >= 0.5;

            return Icon(
              isFilled
                  ? Icons.star
                  : isHalfFilled
                  ? Icons.star_half
                  : Icons.star_border,
              size: starSize,
              color: isFilled || isHalfFilled ? starColor : emptyStarColor,
            );
          }),
        ),

        const SizedBox(width: 4),

        // Hiển thị số đánh giá
        if (showTotalReviews)
          Text(
            '${rating.toStringAsFixed(1)} (${totalReviews} đánh giá)',
            style:
                textStyle ??
                TextStyle(
                  fontSize: starSize * 0.8,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
      ],
    );
  }
}

class RatingBar extends StatefulWidget {
  final int initialRating;
  final Function(int) onRatingChanged;
  final double starSize;
  final Color starColor;
  final Color emptyStarColor;
  final bool allowHalfRating;

  const RatingBar({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.starSize = 24.0,
    this.starColor = Colors.amber,
    this.emptyStarColor = Colors.grey,
    this.allowHalfRating = false,
  });

  @override
  State<RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<RatingBar> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = index + 1;
            });
            widget.onRatingChanged(_currentRating);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              index < _currentRating ? Icons.star : Icons.star_border,
              size: widget.starSize,
              color: index < _currentRating
                  ? widget.starColor
                  : widget.emptyStarColor,
            ),
          ),
        );
      }),
    );
  }
}

class RatingStats extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // {rating: count}

  const RatingStats({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                RatingDisplay(
                  rating: averageRating,
                  totalReviews: totalReviews,
                  starSize: 20,
                ),
              ],
            ),

            if (totalReviews > 0) ...[
              const SizedBox(height: 16),
              const Text(
                'Phân bố đánh giá:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Hiển thị phân bố đánh giá
              ...List.generate(5, (index) {
                final rating = 5 - index;
                final count = ratingDistribution[rating] ?? 0;
                final percentage = totalReviews > 0
                    ? (count / totalReviews) * 100
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      // Số sao
                      SizedBox(
                        width: 60,
                        child: Row(
                          children: [
                            Text('$rating'),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ),

                      // Thanh tiến trình
                      Expanded(
                        child: Container(
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: percentage / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Số lượng và phần trăm
                      SizedBox(
                        width: 80,
                        child: Text(
                          '$count (${percentage.toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
