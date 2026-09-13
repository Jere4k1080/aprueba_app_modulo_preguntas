import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const medalEmoji = {
  'bronze': '🥉',
  'silver': '🥈',
  'gold': '🥇',
  'diamond': '💎',
  'platinum': '⬡',
};

class MedalCoin extends StatelessWidget {
  const MedalCoin(this.tier, {super.key, this.size = 28});
  final String tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.medalColor(tier);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.5), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(medalEmoji[tier] ?? '🏅', style: TextStyle(fontSize: size * 0.46)),
    );
  }
}
