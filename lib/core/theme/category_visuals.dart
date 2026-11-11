import 'package:flutter/material.dart';

import 'package:knotes/features/bodega/models/category_model.dart';

extension CategoryVisuals on CategoryModel {
  IconData get iconData {
    switch (iconKey) {
      case 'fish':
        return Icons.set_meal_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'home':
        return Icons.fort_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'potion':
        return Icons.medication_liquid_rounded;
      case 'boss':
        return Icons.warning_amber_rounded;
      case 'energy':
        return Icons.bolt_rounded;
      case 'loot':
        return Icons.shopping_bag_rounded;
      case 'transport':
        return Icons.rocket_launch_rounded;
      case 'quest':
        return Icons.military_tech_rounded;
      case 'gift':
        return Icons.redeem_rounded;
      case 'gem':
        return Icons.diamond_rounded;
      case 'coins':
        return Icons.monetization_on_rounded;
      case 'transfer':
        return Icons.sync_alt_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}
