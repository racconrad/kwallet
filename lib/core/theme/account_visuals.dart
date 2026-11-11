import 'package:flutter/material.dart';

import 'package:knotes/core/theme/knotes_theme.dart';
import 'package:knotes/features/bodega/models/account.dart';

const accountIcons = <String, (IconData, String)>{
  'wallet': (Icons.wallet_outlined, 'Billetera'),
  'bank': (Icons.account_balance_outlined, 'Banco'),
  'savings': (Icons.savings_outlined, 'Ahorro'),
  'card': (Icons.credit_card_rounded, 'Tarjeta'),
  'home': (Icons.home_outlined, 'Casa'),
  'travel': (Icons.flight_outlined, 'Viajes'),
  'goal': (Icons.flag_outlined, 'Meta'),
  'work': (Icons.work_outline_rounded, 'Trabajo'),
};

extension AccountVisuals on Account {
  Color get displayColor {
    final hsl = HSLColor.fromColor(Color(colorValue));
    return hsl
        .withLightness(
          KnotesTheme.isDark
              ? hsl.lightness.clamp(.65, .82)
              : hsl.lightness.clamp(.24, .38),
        )
        .toColor();
  }

  IconData get iconData => accountIcons[iconKey]?.$1 ?? Icons.wallet_outlined;
}
