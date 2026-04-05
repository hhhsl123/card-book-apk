import 'package:flutter/material.dart';
import '../models/data.dart';

class CardTile extends StatelessWidget {
  final CardItem card;
  final bool selected;
  final VoidCallback onTap;

  const CardTile({super.key, required this.card, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBad = card.bad;
    final isSold = card.sold && !card.bad;

    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    double opacity = 1.0;

    if (selected) {
      borderColor = Theme.of(context).colorScheme.primary;
      bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    }
    if (isBad) {
      borderColor = Colors.red;
      bgColor = Colors.red.shade50;
      opacity = 0.6;
    } else if (isSold) {
      opacity = 0.5;
      bgColor = Colors.grey.shade100;
    }

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSold && card.soldBy != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(99)),
                  child: Text(card.soldBy!, style: const TextStyle(fontSize: 9, color: Colors.white)),
                ),
              if (isBad)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(99)),
                  child: const Text('坏卡', style: TextStyle(fontSize: 9, color: Colors.white)),
                ),
              const SizedBox(height: 2),
              Text(
                card.label,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSold) Text('已卖', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}
